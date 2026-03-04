// Bluetooth Low Energy — sync sessions to the phone app
//
// The phone connects, writes "GET_SESSION" when it wants data, and we stream
// it back in binary packets.

#pragma once
#ifndef DEBUG_GONDOLIER
#define DEBUG_GONDOLIER 0
#endif

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <BLESecurity.h>
#include <Arduino.h>

//  BLE UUIDs
#define BLE_SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define BLE_CHAR_COMMAND_UUID   "12345678-1234-1234-1234-123456789ab0"
#define BLE_CHAR_DATA_UUID      "12345678-1234-1234-1234-123456789ab1"
#define BLE_CHAR_STATUS_UUID    "12345678-1234-1234-1234-123456789ab2"

#define BLE_DEVICE_NAME         "Gondolier"

// Transfer protocol 
// COMMAND (phone writes): "GET_SESSION" = request data, "PING" = connectivity check
// DATA (ESP32 notifies): binary packets [uint8 type][uint16 seq][payload]
//   PKT_METADATA: strokeCount, durationS, split (tenths)
//   PKT_STROKES:  up to 5 uint32 timestamps per packet
//   PKT_END:      end-of-stream marker
#define PKT_METADATA  0x01
#define PKT_STROKES   0x02
#define PKT_END       0xFF
#define BLE_MTU       512   ///< Negotiate higher MTU in Flutter (default 20 is too small)

// Session data
struct SessionData {
  uint32_t  strokeCount;
  uint32_t  durationSeconds;
  float     avgSplitSeconds;
  uint32_t* strokeTimestampsMs;
  uint32_t  timestampCount;
};

static SessionData _session = {0, 0, 0.0f, nullptr, 0};

// BLE state 
static BLEServer*          _bleServer    = nullptr;
static BLECharacteristic*  _charCommand  = nullptr;
static BLECharacteristic*  _charData     = nullptr;
static BLECharacteristic*  _charStatus   = nullptr;
static bool                _bleConnected = false;
static bool                _sendRequested = false;

// BLE callbacks

// Handles BLE server. restarts advertising on disconnect
class NetServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* s) override {
    _bleConnected = true;
#if DEBUG_GONDOLIER
    Serial.println("[BLE] Client connected");
#endif
  }
  void onDisconnect(BLEServer* s) override {
    _bleConnected = false;
    _sendRequested = false;
#if DEBUG_GONDOLIER
    Serial.println("[BLE] Client disconnected — restarting advertising");
#endif
    BLEDevice::startAdvertising();
  }
};

// Set send data flag when phone sends command
class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String cmd = c->getValue().c_str();
    cmd.trim();
#if DEBUG_GONDOLIER
    Serial.printf("[BLE] CMD: %s\n", cmd.c_str());
#endif
    if (cmd == "GET_SESSION") {
      _sendRequested = true;
    }
  }
};

// Initialisation 

// Set up Bluetooth: device name, service, characteristics, advertising.
void net_init() {
  BLEDevice::init(BLE_DEVICE_NAME);
  BLEDevice::setMTU(BLE_MTU);
  BLESecurity *pSecurity = new BLESecurity();

  // No bonding, no MITM, no secure connections
  pSecurity->setAuthenticationMode(ESP_LE_AUTH_NO_BOND);
  pSecurity->setCapability(ESP_IO_CAP_NONE);
  pSecurity->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);

  _bleServer = BLEDevice::createServer();
  _bleServer->setCallbacks(new NetServerCallbacks());

  BLEService* svc = _bleServer->createService(BLE_SERVICE_UUID);

  // Command characteristic (phone writes)
  _charCommand = svc->createCharacteristic(
      BLE_CHAR_COMMAND_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  _charCommand->setCallbacks(new CommandCallbacks());

  // Data characteristic (ESP32 notifies)
  _charData = svc->createCharacteristic(
      BLE_CHAR_DATA_UUID,
      BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ);
  _charData->addDescriptor(new BLE2902());

  // Status characteristic (ESP32 readable string)
  _charStatus = svc->createCharacteristic(
      BLE_CHAR_STATUS_UUID,
      BLECharacteristic::PROPERTY_READ);
  _charStatus->setValue("IDLE");

  svc->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(BLE_SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);  // helps iOS connection
  BLEDevice::startAdvertising();

#if DEBUG_GONDOLIER
  Serial.println("[BLE] Advertising as \"" BLE_DEVICE_NAME "\"");
#endif
}

// Session data

// gets the data ready for transmission to phone when the end session button is pressed
void net_setSession(uint32_t strokes, uint32_t durSec, float split,
                    uint32_t* timestamps, uint32_t tsCount) {
  _session.strokeCount        = strokes;
  _session.durationSeconds    = durSec;
  _session.avgSplitSeconds    = split;
  _session.strokeTimestampsMs = timestamps;
  _session.timestampCount     = tsCount;

  if (_charStatus) _charStatus->setValue("SESSION_READY");
}

// Sends one packet. Small delay between packets so the stack can keep up.
static void _bleSend(const uint8_t* buf, size_t len) {
  if (!_bleConnected || !_charData) return;
  _charData->setValue(const_cast<uint8_t*>(buf), len);
  _charData->notify();
  delay(20);
}

// Session transfer
// Sends metadata, then stroke timestamps, then an end marker.
void net_sendSession() {
  if (!_bleConnected) return;

#if DEBUG_GONDOLIER
  Serial.println("[BLE] Sending session...");
#endif
  _charStatus->setValue("SENDING");

  // Packet 1, metadata
  uint8_t meta[11];
  meta[0] = PKT_METADATA;
  meta[1] = 0; meta[2] = 0;  // seq 0
  memcpy(meta + 3, &_session.strokeCount,     4);
  memcpy(meta + 7, &_session.durationSeconds, 4);
  uint16_t splitTenths = (uint16_t)(_session.avgSplitSeconds * 10.0f);
  uint8_t meta2[13];
  memcpy(meta2, meta, 11);
  memcpy(meta2 + 11, &splitTenths, 2);
  _bleSend(meta2, 13);

  // Packets 2, 3, 4, 5: stroke timestamps, 5 per packet
  if (_session.strokeTimestampsMs && _session.timestampCount > 0) {
    uint16_t seq = 1;
    uint32_t i   = 0;
    while (i < _session.timestampCount) {
      uint32_t count = min((uint32_t)5, _session.timestampCount - i);
      uint8_t pkt[3 + 4 * 5];
      pkt[0] = PKT_STROKES;
      memcpy(pkt + 1, &seq, 2);
      for (uint32_t j = 0; j < count; j++) {
        memcpy(pkt + 3 + j * 4, &_session.strokeTimestampsMs[i + j], 4);
      }
      _bleSend(pkt, 3 + count * 4);
      i += count;
      seq++;
    }
  }

  // End packet
  uint8_t endPkt[3] = {PKT_END, 0xFF, 0xFF};
  _bleSend(endPkt, 3);

  _charStatus->setValue("IDLE");
  _sendRequested = false;
#if DEBUG_GONDOLIER
  Serial.println("[BLE] Session sent.");
#endif
}

//  Main loop

// Call this every loop. If we're connected and the phone asked for data, it is sent.
void net_update() {
  if (_bleConnected && _sendRequested) {
    net_sendSession();
  }
}

bool net_isConnected() { return _bleConnected; }
