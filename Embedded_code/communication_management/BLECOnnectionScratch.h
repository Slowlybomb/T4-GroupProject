#ifndef T4_GROUPPROJECT_BLECONNECTIONSCRATCH_H
#define T4_GROUPPROJECT_BLECONNECTIONSCRATCH_H

#include <algorithm>
#include <Arduino.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <NimBLEDevice.h>

// UUIDs (TODO change later)
static const char *kServiceUUID = "grcb0001-7a3b-4a1a-9c1b-111111111111";
static const char *kCtrlUUID = "grcb0002-7a3b-4a1a-9c1b-111111111111"; // Write
static const char *kDataUUID = "grcb0003-7a3b-4a1a-9c1b-111111111111"; // Notify
static const char *kStatUUID = "grcb0004-7a3b-4a1a-9c1b-111111111111"; // Notify

// binary protocol
// Control (client->device), little-endian
//
// CMD_LIST  = 0x01, no payload, just ask for list of sessions
// CMD_OPEN  = 0x02 {u16 sessionId}, ask to open session, reply with size or error
// CMD_READ  = 0x03 {u16 sessionId, u32 offset, u16 length}, ask to read chunk of specified size and offset
// CMD_ACK   = 0x04 {u16 seq}, ACK for received chunk
// CMD_CLOSE = 0x05 {u16 sessionId}, ask to close session
//
// Data (device->client) notification payload:
// {u16 seq, u32 offset, u16 payload_len, bytes[payload_len]}, where seq is a sequence number for reliability (ACKed by client), offset is file offset, and payload_len is length of payload in bytes (<= MAX_PAYLOAD).

enum : uint8_t {
    CMD_LIST = 0x01,
    CMD_OPEN = 0x02,
    CMD_READ = 0x03,
    CMD_ACK = 0x04,
    CMD_CLOSE = 0x05,
};

static uint16_t rd16(const uint8_t *p) { return uint16_t(p[0]) | (uint16_t(p[1]) << 8); }

static uint32_t rd32(const uint8_t *p) {
    return static_cast<uint32_t>(p[0]) | (uint32_t(p[1]) << 8) | (uint32_t(p[2]) << 16) | (uint32_t(p[3]) << 24);
}

static void wr16(uint8_t *p, uint16_t v) {
    p[0] = v & 0xFF;
    p[1] = (v >> 8) & 0xFF;
}

static void wr32(uint8_t *p, uint32_t v) {
    p[0] = v & 0xFF;
    p[1] = (v >> 8) & 0xFF;
    p[2] = (v >> 16) & 0xFF;
    p[3] = (v >> 24) & 0xFF;
}

// Mock Session:
// fake "session" consisting of ASCII timestamps separated by '\n'.
struct SessionSource {
    static constexpr uint16_t kSessionId = 1;

    // Mock data
    const char *data =
            "1700000000\n"
            "1700000002\n"
            "1700000005\n"
            "1700000007\n"
            "1700000010\n";

    size_t size() const { return strlen(data); }

    // Read from [offset, offset+len), returns num bytes read
    size_t read(const uint32_t offset, const uint16_t len, uint8_t *out) const {
        const size_t sz = size();
        if (offset >= sz) return 0;
        const size_t n = std::min<size_t>(len, sz - offset);
        memcpy(out, data + offset, n);
        return n;
    }
};

static SessionSource gSession;

//  BLE globals
static NimBLEServer *gServer = nullptr;
static NimBLECharacteristic *gCtrl = nullptr;
static NimBLECharacteristic *gData = nullptr;
static NimBLECharacteristic *gStat = nullptr;

static bool gConnected = false;

// Stop-and-wait reliability state, general info on in-flight chunk
static uint16_t gNextSeq = 1;
static bool gWaitingAck = false;
static uint16_t gWaitingSeq = 0;
static uint32_t gWaitingOffset = 0;
static uint16_t gWaitingLen = 0;
static uint32_t gLastSendMs = 0;

// TODO tune
static const uint32_t ACK_TIMEOUT_MS = 500; // resend if no ACK quickly
static const uint16_t MAX_PAYLOAD = 160; // payload max size (bytes)

static void notifyStatus(const char *msg) {
    if (!gConnected) return;
    gStat->setValue((uint8_t *) msg, strlen(msg));
    gStat->notify();
}

// Server callbacks
class ServerCB : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer *s, NimBLEConnInfo &ci) override {
        gConnected = true;
        notifyStatus("CONNECTED");
    }

    void onDisconnect(NimBLEServer *s, NimBLEConnInfo &ci, int reason) override {
        (void) reason;
        gConnected = false;
        gWaitingAck = false;
        notifyStatus("DISCONNECTED");
        NimBLEDevice::startAdvertising();
    }
};

// Control characteristic callbacks
class CtrlCB : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic *c, NimBLEConnInfo &ci) override {
        std::string v = c->getValue();
        if (v.size() < 1) return;

        const uint8_t *p = (const uint8_t *) v.data();
        const uint8_t cmd = p[0];

        switch (cmd) {
            case CMD_LIST: {
                // just print "SESSION:1 size:<n>"
                char buf[64];
                snprintf(buf, sizeof(buf), "LIST 1 %u", (unsigned) gSession.size());
                notifyStatus(buf);
                break;
            }
            case CMD_OPEN: {
                if (v.size() < 1 + 2) {
                    notifyStatus("OPEN_BADLEN");
                    break;
                }
                uint16_t sid = rd16(p + 1);
                if (sid != SessionSource::kSessionId) {
                    notifyStatus("OPEN_NOSESSION");
                    break;
                }

                char buf[64];
                snprintf(buf, sizeof(buf), "OPEN_OK %u", (unsigned) gSession.size());
                notifyStatus(buf);
                break;
            }
            case CMD_READ: {
                if (v.size() < 1 + 2 + 4 + 2) {
                    notifyStatus("READ_BADLEN");
                    break;
                }
                uint16_t sid = rd16(p + 1);
                uint32_t off = rd32(p + 3);
                uint16_t len = rd16(p + 7);

                if (sid != SessionSource::kSessionId) {
                    notifyStatus("READ_NOSESSION");
                    break;
                }
                if (!gConnected) break;

                // If chunk in-flight, ignore new READ (TODO replace with more elegant solution)
                if (gWaitingAck) {
                    notifyStatus("READ_BUSY");
                    break;
                }

                // Schedule first send immediately; loop() handles retransmit and next chunks
                gWaitingOffset = off;
                gWaitingLen = len;
                gWaitingAck = false; // not yet sent
                notifyStatus("READ_OK");
                break;
            }
            case CMD_ACK: {
                if (v.size() < 1 + 2) {
                    notifyStatus("ACK_BADLEN");
                    break;
                }
                uint16_t seq = rd16(p + 1);
                if (gWaitingAck && seq == gWaitingSeq) {
                    gWaitingAck = false; // allow next chunk to send
                }
                break;
            }
            case CMD_CLOSE: {
                notifyStatus("CLOSE_OK");
                break;
            }
            default:
                notifyStatus("UNKNOWN_CMD");
                break;
        }
    }
};

// Data send logic
static void sendOneChunkIfPossible() {
    if (!gConnected) return;

    // If waiting for ACK, maybe retransmit
    if (gWaitingAck) {
        if (millis() - gLastSendMs >= ACK_TIMEOUT_MS) {
            // retransmit last chunk (same seq)
            uint8_t payload[MAX_PAYLOAD];
            size_t n = gSession.read(gWaitingOffset, gWaitingLen, payload);

            uint8_t pkt[2 + 4 + 2 + MAX_PAYLOAD];
            wr16(pkt + 0, gWaitingSeq);
            wr32(pkt + 2, gWaitingOffset);
            wr16(pkt + 6, (uint16_t) n);
            memcpy(pkt + 8, payload, n);

            gData->setValue(pkt, 8 + n);
            gData->notify();
            gLastSendMs = millis();
        }
        return;
    }

    // Not waiting for ACK: send next chunk if there is work
    if (gWaitingLen == 0) return;

    uint16_t thisLen = min<uint16_t>(gWaitingLen, MAX_PAYLOAD);
    uint8_t payload[MAX_PAYLOAD];
    size_t n = gSession.read(gWaitingOffset, thisLen, payload);

    if (n == 0) {
        // End of file or nothing more to send
        notifyStatus("READ_DONE");
        gWaitingLen = 0;
        return;
    }

    uint16_t seq = gNextSeq++;

    uint8_t pkt[2 + 4 + 2 + MAX_PAYLOAD];
    wr16(pkt + 0, seq);
    wr32(pkt + 2, gWaitingOffset);
    wr16(pkt + 6, (uint16_t) n);
    memcpy(pkt + 8, payload, n);

    gData->setValue(pkt, 8 + n);
    gData->notify();

    // Mark in-flight for ACK
    gWaitingAck = true;
    gWaitingSeq = seq;
    gLastSendMs = millis();

    // Advance
    gWaitingOffset += (uint32_t) n;
    gWaitingLen -= (uint16_t) n;
}


// Setup and loop
void setup() {
    Serial.begin(115200);
    delay(200);

    NimBLEDevice::init("RowingComputer");
    NimBLEDevice::setPower(ESP_PWR_LVL_P9); // tweak as needed

    gServer = NimBLEDevice::createServer();
    gServer->setCallbacks(new ServerCB());

    NimBLEService *svc = gServer->createService(kServiceUUID);

    gCtrl = svc->createCharacteristic(
        kCtrlUUID,
        NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
    );
    gCtrl->setCallbacks(new CtrlCB());

    gData = svc->createCharacteristic(
        kDataUUID,
        NIMBLE_PROPERTY::NOTIFY
    );

    gStat = svc->createCharacteristic(
        kStatUUID,
        NIMBLE_PROPERTY::NOTIFY
    );

    svc->start();

    NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
    adv->setName("GondolierRowComputer");
    adv->addServiceUUID(kServiceUUID);
    //adv->setScanResponse(true);
    adv->start();

    Serial.println("BLE advertising started.");
    notifyStatus("BOOT");
}

void loop() {
    sendOneChunkIfPossible();
    delay(5);
}


#endif //T4_GROUPPROJECT_BLECONNECTIONSCRATCH_H