#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <optional>
#include <queue>
#include <random>
#include <string>
#include <vector>


// Packets

enum class CmdType : uint8_t { READ = 1, ACK = 2 };

struct ReadCmd {
    uint32_t offset;
    uint32_t length;
};

struct AckCmd {
    uint16_t seq;
};

struct Command {
    CmdType type;

    union {
        ReadCmd read;
        AckCmd ack;
    } u{};
};

struct DataPkt {
    uint16_t seq;
    uint32_t offset;
    std::vector<uint8_t> payload;
};

// Link simulator
// Two queues: client->device commands, device->client data.
// drops packets to simulate unreliable BLE notifications.

struct LinkSim {
    std::queue<Command> c2d;
    std::queue<DataPkt> d2c;

    // Drop every Nth data packet (0 = never)
    //int drop_every_n = 0;
    float dropChance = 0; // 0 to 1, chance to drop each packet independently
    int sent_count = 0;

    void sendCmd(const Command &cmd) {
        c2d.push(cmd);
    }

    void sendData(const DataPkt &pkt) {
        sent_count++;
        // if (drop_every_n > 0 && (sent_count % drop_every_n) == 0) {
        //     // drop intentionally
        //     return;
        // }
        if (dropChance > 0.0f) {
            static std::mt19937 rng(std::random_device{}());
            std::uniform_real_distribution<float> dist(0.0f, 1.0f);
            if (dist(rng) < dropChance) {
                // drop this packet
                return;
            }
        }
        d2c.push(pkt);
    }

    std::optional<Command> receiveCmd() {
        if (c2d.empty()) return std::nullopt;
        auto v = c2d.front();
        c2d.pop();
        return v;
    }

    std::optional<DataPkt> recieveCmd() {
        if (d2c.empty()) return std::nullopt;
        auto v = d2c.front();
        d2c.pop();
        return v;
    }
};

// Device simulator

struct DeviceSim {
    LinkSim &link;
    std::vector<uint8_t> file_bytes;

    uint16_t next_seq = 1;

    // simplistic "in flight" tracking for resend
    struct InFlight {
        uint16_t seq;
        uint32_t offset;
        std::vector<uint8_t> payload;
        int ticks_since_sent = 0;
    };

    std::optional<InFlight> inflight;

    struct PendingRead {
        uint32_t offset;
        uint32_t length;
    };

    std::optional<PendingRead> pending_read;

    explicit DeviceSim(LinkSim &l, std::vector<uint8_t> bytes)
        : link(l), file_bytes(std::move(bytes)) {
    }

    void tick() {
        while (const auto cmd = link.receiveCmd()) {
            if (cmd->type == CmdType::READ) {
                pending_read = PendingRead{cmd->u.read.offset, cmd->u.read.length};
            } else if (cmd->type == CmdType::ACK) {
                handleAck(cmd->u.ack.seq);
            }
        }

        // Simple resend timeout mechanism/ARQ (tick-based), change to time-based later
        if (inflight) {
            inflight->ticks_since_sent++;
            if (inflight->ticks_since_sent > 5) {
                // on timeout resend the same packet

                //TODO try sending previous payload with current seq, to see if compare is actually working

                std::cerr << "Resending packet seq=" << inflight->seq << " offset=" << inflight->offset
                        << " size=" << inflight->payload.size() << "\n";
                DataPkt pkt{inflight->seq, inflight->offset, inflight->payload};
                link.sendData(pkt);
                inflight->ticks_since_sent = 0;
            }
        }

        // Process pending read if no packet in flight
        if (pending_read && !inflight) {
            sendNextChunk();
        }
    }

    void sendNextChunk() {
        if (!pending_read) return;

        const uint32_t end = std::min<uint32_t>(pending_read->offset + pending_read->length, file_bytes.size());
        const uint32_t cur = pending_read->offset;

        if (cur >= end) {
            pending_read.reset();
            return;
        }

        // Serve in chunks, BLE-like. Loosely mimicks chunking needed for file transfer over GATT
        constexpr uint32_t CHUNK = 160;
        uint32_t n = std::min<uint32_t>(CHUNK, end - cur);

        DataPkt pkt;
        pkt.seq = next_seq++;
        pkt.offset = cur;
        pkt.payload.assign(file_bytes.begin() + cur, file_bytes.begin() + cur + n);

        // Send and remember until ACKed
        link.sendData(pkt);
        inflight = InFlight{pkt.seq, pkt.offset, pkt.payload, 0};

        // Update offset for next chunk
        pending_read->offset += n;
        pending_read->length -= n;
    }

    void handleAck(const uint16_t seq) {
        if (inflight && inflight->seq == seq) {
            inflight.reset();
        }
    }
};

// Client

struct Client {
    LinkSim &link;

    std::vector<uint8_t> out;
    uint32_t expected_size = 0;

    // Track received (byte-range receipt map)
    // apparently a special case in C++: vector<bool> is a bitset specialization, so different reference semantics, shouldn't be a problem
    std::vector<bool> received;

    explicit Client(LinkSim &l) : link(l) {
    }

    void startDownload(const uint32_t total_size) {
        expected_size = total_size;
        out.assign(expected_size, 0);
        received.assign(expected_size, false);

        // Request entire file (device will chunk)
        Command cmd;
        cmd.type = CmdType::READ;
        cmd.u.read = ReadCmd{0, expected_size};
        link.sendCmd(cmd);
    }

    void tick() {
        while (const auto pkt = link.recieveCmd()) {
            // Write payload into output buffer
            uint32_t off = pkt->offset;
            std::cout << "Received packet seq=" << pkt->seq << " offset=" << pkt->offset
                    << " size=" << pkt->payload.size() << "\n";
            if (off + pkt->payload.size() <= out.size()) {
                std::memcpy(out.data() + off, pkt->payload.data(), pkt->payload.size());
                for (size_t i = 0; i < pkt->payload.size(); i++) {
                    received[off + i] = true;
                }
            }

            // ACK
            Command ack;
            ack.type = CmdType::ACK;
            ack.u.ack = AckCmd{pkt->seq};
            link.sendCmd(ack);
        }
    }

    [[nodiscard]] bool done() const {
        for (const bool b : received) if (!b) return false;
        return true;
    }
};


// Helper Functions

static std::vector<uint8_t> readAllBytes(const std::string &path) {
    std::ifstream f(path, std::ios::binary); //input file stream

    if (!f) throw std::runtime_error("Failed to open " + path);

    //get file size for buffer allocation
    f.seekg(0, std::ios::end);
    const auto size = static_cast<size_t>(f.tellg());
    f.seekg(0, std::ios::beg);

    std::vector<uint8_t> buf(size);

    //reinterpret buffer as char* for reading
    f.read(reinterpret_cast<char *>(buf.data()), static_cast<std::streamsize>(size));
    return buf;
}

static bool compareBytes(const std::vector<uint8_t> &a, const std::vector<uint8_t> &b) {
    return a.size() == b.size() && std::memcmp(a.data(), b.data(), a.size()) == 0; //0 if equal
}


int main() {
    try {
        const std::string path = "Embedded_code/communication_management/session.txt";
        const auto original = readAllBytes(path);

        LinkSim link;
        link.dropChance = 0.1; // simulate packet loss

        DeviceSim device(link, original);
        Client client(link);

        client.startDownload(static_cast<uint32_t>(original.size()));

        // tick-based simulation (for simplicity and speed)
        for (int t = 0; t < 500000 && !client.done(); t++) {
            device.tick();
            client.tick();
        }

        if (!client.done()) {
            std::cerr << "Download failed to complete\n";
            return 2;
        }

        // Verify integrity
        if (!compareBytes(original, client.out)) {
            std::cerr << "Mismatch: Reassembled file differs.\n";
            return 3;
        }

        std::cout << "OK: Downloaded " << client.out.size() << " bytes, matches original.\n";
        return 0;
    } catch (const std::exception &e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }
}
