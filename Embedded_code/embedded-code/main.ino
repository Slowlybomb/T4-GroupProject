// Gondolier Rowing Computer
//
// This is the main script for the Gondalier smart rowing tracker made by group 4 as part of the CS3306 computer science module.
//
// Uses a small neural network to detect rowing strokes from the accelerometer.
// Saves stroke times to SD card and can sync sessions to your phone over Bluetooth.
//
// Hardware: ESP32-S3, QMI8658C accelerometer, ILI9341 display, SD card

//turn on and off serial debugging
#ifndef DEBUG_GONDOLIER
#define DEBUG_GONDOLIER 1   // 1 debugging on,0 = debugging off
#endif

#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>
#include <Fonts/Org_01.h>

// import headers
#include "accelerometer.h"
#include "model.h"
#include "Display.h"
#include "networking.h"

// Pins
#define I2C_SDA  42
#define I2C_SCL  41

#define SD_CS    10
#define SD_MOSI  35
#define SD_MISO  37
#define SD_SCK   36

#define START_BUTTON_PIN  5
#define STOP_BUTTON_PIN   6

Adafruit_ILI9341 display = Adafruit_ILI9341(TFT_CS, TFT_DC, TFT_RST);

//  model config 
#define INFER_INTERVAL_MS    100   // interval to run the infrence on the data
#define DISPLAY_UPDATE_MS    1000  // update the screen every second

// ─── Session state ───────────────────────────────────────────────────────────
// number of strokes to store, 1000 strokes is roughly 50 minutes 
#define MAX_STROKES 2000

struct Session {
  bool        active;
  uint32_t    startMs;
  uint32_t    strokeCount;
  uint32_t*   strokeTimestamps;
  uint32_t    lastStrokeMs;
  float       lastSplitSeconds;
};

static Session session = {false, 0, 0, nullptr, 0, 0.0f};

//declaring variables
static File         dataFile;
static String       csvFileName;
static bool         sdReady = false;

// run the ai stroke detection, if its above 80% certainty we count it as a stroke
#define STROKE_THRESHOLD     0.8f
//set delay so that strokes are not detected twice, this is basically debouncing for the AI
#define MIN_STROKE_INTERVAL  500

static bool    _lastAbove  = false;
// time of last inference
static uint32_t _lastInferMs = 0;

// SD helpers

// adds new stroke to the sd card csv
void appendStrokeToSD(uint32_t timestampMs) {
  if (!sdReady || !dataFile) return;
  dataFile.printf("%u\n", timestampMs);
  dataFile.flush();
}

// Stroke detection

// Watches the model score. When it crosses above the threshold, a stroke is counted, saved and the screen is updated.
void checkForStroke(float modelScore) {
  bool above = (modelScore > STROKE_THRESHOLD);
  if (above && !_lastAbove) {
    uint32_t now = millis();
    if (now - session.lastStrokeMs >= MIN_STROKE_INTERVAL) {
      // Debounce passed, count stroke
      if (session.strokeTimestamps && session.strokeCount < MAX_STROKES)
        session.strokeTimestamps[session.strokeCount] = now - session.startMs;

      session.strokeCount++;
      session.lastStrokeMs = now;

      appendStrokeToSD(now - session.startMs);

      // calculating the split time (distance per 500m). since we dont have GPS data and cant get accurate positional information, we estimate the distance per stroke
      float intervalSec = (now - (session.strokeCount > 1
                                  ? session.startMs + session.strokeTimestamps[session.strokeCount - 2]
                                  : session.startMs)) / 1000.0f;
      session.lastSplitSeconds = intervalSec;

      // Update the display
      String splitStr = formatSplit((uint32_t)session.lastSplitSeconds);
      String strokeStr = String(session.strokeCount);
      uint32_t elapsed = (now - session.startMs) / 1000;
      String elapsedStr = formatElapsed(elapsed);
      update_screen(display, strokeStr, splitStr, elapsedStr);

#if DEBUG_GONDOLIER
      Serial.printf("[STROKE] #%u  score=%.2f  elapsed=%us\n",
                    session.strokeCount, modelScore, elapsed);
#endif
    }
  }
  _lastAbove = above;
}

// Session control

// this function starts a new session object, resets the screen and allocates PSRAM for storing stroke data. it also creates the next csv file for data storage
void startSession() {
  if (session.active) return;
  session.active       = true;
  session.startMs      = millis();
  session.strokeCount  = 0;
  session.lastStrokeMs = 0;
  _lastAbove           = false;

  // Allocate stroke timestamp buffer in PSRAM (only once; reuse across sessions)
  if (session.strokeTimestamps == nullptr) {
    session.strokeTimestamps = (uint32_t*)ps_malloc(MAX_STROKES * sizeof(uint32_t));
    if (!session.strokeTimestamps) {
      Serial.println("[MAIN] WARNING: PSRAM alloc for stroke timestamps failed");
    }
  }

  if (sdReady) {
    int n = 1;
    while (true) {
      csvFileName = "/rowing_" + String(n) + ".csv";
      if (!SD.exists(csvFileName.c_str())) break;
      n++;
    }
    dataFile = SD.open(csvFileName.c_str(), FILE_WRITE);
    if (dataFile) dataFile.println("StrokeTimestamp_ms");
  }

  display.fillScreen(0x0000);
  show_ui(display);
#if DEBUG_GONDOLIER
  Serial.println("[MAIN] Session started");
#endif
}

// stops the rowing session object, gets the data ready for bluetooth transmittion
void stopSession() {
  if (!session.active) return;
  session.active = false;

  if (sdReady) {
    dataFile.close();
  }

  uint32_t durSec = (millis() - session.startMs) / 1000;

#if DEBUG_GONDOLIER
  Serial.printf("[MAIN] Session stopped. Strokes: %u  Duration: %us\n",
                session.strokeCount, durSec);
#endif

  // Hand data to networking layer
  net_setSession(session.strokeCount, durSec, session.lastSplitSeconds,
                 session.strokeTimestamps, session.strokeCount);

  show_message(display, "Session saved!\nConnect app to sync.");
}

// Button handling

// start and stop buttons
void checkButtons() {
  static int     lastStart = HIGH, lastStop = HIGH;
  static uint32_t lastStartMs = 0, lastStopMs = 0;

  int s = digitalRead(START_BUTTON_PIN);
  int e = digitalRead(STOP_BUTTON_PIN);

  if (s == LOW && lastStart == HIGH && millis() - lastStartMs > 500) {
    startSession();
    lastStartMs = millis();
  }
  if (e == LOW && lastStop == HIGH && millis() - lastStopMs > 500) {
    stopSession();
    lastStopMs = millis();
  }
  lastStart = s;
  lastStop  = e;
}

// setup()

void setup() {
  Serial.begin(115200);
  delay(1500);
#if DEBUG_GONDOLIER
  Serial.println("\n Gondolier Rowing Tracker ");
#endif

  // Buttons
  pinMode(START_BUTTON_PIN, INPUT_PULLUP);
  pinMode(STOP_BUTTON_PIN,  INPUT_PULLUP);

  // Display
  display.begin();
  display.setRotation(1);  // landscape
  display.fillScreen(0x0000);
  splashscreen(display);
  delay(2000);
  display.fillScreen(0x0000);

  // SD card
  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);
  sdReady = SD.begin(SD_CS);
#if DEBUG_GONDOLIER
  Serial.printf("[SD] %s\n", sdReady ? "Ready" : "Not found (continuing without SD)");
#endif

  // Accelerometer
  if (!accel_init(I2C_SDA, I2C_SCL)) {
    Serial.println("[MAIN] FATAL: Accelerometer init failed");
    while (1);
  }

  // TFLite model
  if (!model_init()) {
    Serial.println("[MAIN] WARNING: Model init failed (stroke detection disabled)");
  }

  // BLE
  net_init();

  // Show idle UI
  show_ui(display);
  show_message(display, "Press START", C_WHITE);

#if DEBUG_GONDOLIER
  Serial.println("[MAIN] Ready. Press START to begin.");
#endif
}

// loop()

void loop() {
  checkButtons();
  accel_drainFIFO();

  // Run inference
  uint32_t now = millis();
  if (session.active && now - _lastInferMs >= INFER_INTERVAL_MS) {
    _lastInferMs = now;
    float score = model_inferFromAccel();
    if (score >= 0.0f) {
      checkForStroke(score);
    }
  }

  // Update elapsed time on display
  {
    static uint32_t lastDisplayMs = 0;
    if (session.active && now - lastDisplayMs >= DISPLAY_UPDATE_MS) {
      lastDisplayMs = now;
      update_timer(display, formatElapsed((now - session.startMs) / 1000U));
    }
  }

  // BLE transfer
  net_update();

  // Update BT icon
  {
    static bool lastBle = false;
    bool ble = net_isConnected();
    if (ble != lastBle) {
      show_bluetooth_status(display, ble);
      lastBle = ble;
    }
  }

  delay(5);
}
