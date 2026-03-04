// import libraries
#include <Wire.h>
#include <SD.h>
#include <SPI.h>
#include <math.h>

// TensorFlow Lite Micro
#include "TensorFlowLite.h"
#include "tensorflow/lite/micro/all_ops_resolver.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/schema/schema_generated.h"
#include "tensorflow/lite/version.h"

// Model data (generated from model.tflite)
// Provide model_tflite[] and model_tflite_len in model_data.h
#include "model_data.h"

// I2C Pins
#define I2C_SDA 42
#define I2C_SCL 41

// SD Card Pins
#define SD_CS 10
#define SD_MOSI 35
#define SD_MISO 37
#define SD_SCK 36

// Button Pins
#define START_BUTTON_PIN 5
#define STOP_BUTTON_PIN 6

// Button state tracking
volatile bool startButtonPressed = false;
volatile bool stopButtonPressed = false;

// I2C address
#define QMI8658_ADDR 0x6B

// Register definitions
#define REG_WHO_AM_I    0x00 
#define REG_CTRL1       0x02 
#define REG_CTRL2       0x03 
#define REG_CTRL7       0x08 
#define REG_CTRL9       0x0A
#define REG_FIFO_CTRL   0x14
#define REG_FIFO_SMPL   0x15
#define REG_FIFO_STATUS 0x16
#define REG_FIFO_DATA   0x17
#define REG_STATUSINT   0x2D
#define REG_RESET       0x60

// Constants
#define RESET_CMD       0xB0
#define ACC_ENABLE      0x01
#define ACC_ODR_125HZ   0x04
#define ACC_RANGE_4G    0x01
#define ACC_HI_RES      0x10
#define CMD_REQ_FIFO    0x05

// PSRAM Buffer Configuration
#define BUFFER_SIZE 5000
#define FLUSH_INTERVAL_MS 5000

// Rolling magnitude filter configuration
#define MAG_WINDOW_SIZE 50

// Filter history for model input
#define INFERENCE_WINDOW_SIZE 850
#define FILTER_HISTORY_SIZE 900  // must be >= INFERENCE_WINDOW_SIZE

// Data structures
struct AccelSample {
  uint32_t timestamp;
  int16_t x;
  int16_t y;
  int16_t z;
};

// PSRAM buffer
AccelSample* psramBuffer = nullptr;
uint32_t bufferIndex = 0;
uint32_t totalSamples = 0;
uint32_t lastFlushTime = 0;
uint32_t sessionStartTime = 0;
bool isRecording = false;

File dataFile;
String currentFileName;

// Rolling magnitude filter state (|Y,Z| magnitude)
float magWindow[MAG_WINDOW_SIZE] = {0};
int magIndex = 0;
int magCount = 0;
float magSum = 0.0f;

// Filtered magnitude history for inference
float filteredHistory[FILTER_HISTORY_SIZE] = {0};
int filteredIndex = 0;
int filteredCount = 0;

// TensorFlow Lite Micro globals
const tflite::Model* tflModel = nullptr;
tflite::MicroInterpreter* tflInterpreter = nullptr;
tflite::AllOpsResolver tflResolver;
TfLiteTensor* tflInput = nullptr;
TfLiteTensor* tflOutput = nullptr;

// Tensor arena in PSRAM
constexpr int kTensorArenaSize = 60 * 1024;
uint8_t* tensorArena = nullptr;

void runInferenceOnLastWindow(uint32_t timestamp);

void writeReg(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(QMI8658_ADDR);
  Wire.write(reg);
  Wire.write(val);
  Wire.endTransmission();
}

uint8_t readReg(uint8_t reg) {
  Wire.beginTransmission(QMI8658_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)QMI8658_ADDR, (uint8_t)1);
  return Wire.read();
}

bool initSD() {
  Serial.println("\nSD Card Initialization");
  
  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);
  
  if (!SD.begin(SD_CS)) {
    Serial.println("ERROR: SD card initialization failed");
    return false;
  }
  
  uint8_t cardType = SD.cardType();
  if (cardType == CARD_NONE) {
    Serial.println("ERROR: No SD card attached");
    return false;
  }

  return true;
}

bool initPSRAM() {
  Serial.println("\nPSRAM Initialization");
  
  if (!psramFound()) {
    Serial.println("ERROR: PSRAM not found");
    return false;
  }
  
  Serial.printf("PSRAM Total: %d bytes\n", ESP.getPsramSize());
  
  psramBuffer = (AccelSample*)ps_malloc(BUFFER_SIZE * sizeof(AccelSample));
  
  if (psramBuffer == nullptr) {
    Serial.println("ERROR: Failed to allocate PSRAM");
    return false;
  }
  
  Serial.printf("Buffer allocated: %d samples\n", BUFFER_SIZE);
  Serial.println(" PSRAM ready");
  
  return true;
}

bool initTFLite() {
  Serial.println("\nTensorFlow Lite Micro Initialization");

  tensorArena = (uint8_t*)ps_malloc(kTensorArenaSize);
  if (!tensorArena) {
    Serial.println("ERROR: Failed to allocate tensor arena in PSRAM");
    return false;
  }

  tflModel = tflite::GetModel(model_tflite);
  if (tflModel->version() != TFLITE_SCHEMA_VERSION) {
    Serial.println("ERROR: Model schema version mismatch");
    return false;
  }

  tflInterpreter = new tflite::MicroInterpreter(
    tflModel, tflResolver, tensorArena, kTensorArenaSize, nullptr);

  TfLiteStatus allocStatus = tflInterpreter->AllocateTensors();
  if (allocStatus != kTfLiteOk) {
    Serial.println("ERROR: AllocateTensors() failed");
    return false;
  }

  tflInput = tflInterpreter->input(0);
  tflOutput = tflInterpreter->output(0);

  Serial.println("TensorFlow Lite Micro ready");
  return true;
}

String generateFileName() {
  int sessionNum = 1;
  String filename;
  
  while (true) {
    filename = "/rowing_" + String(sessionNum) + ".csv";
    if (!SD.exists(filename.c_str())) {
      break;
    }
    sessionNum++;
  }
  
  return filename;
}

bool startNewSession() {
  if (isRecording) {
    Serial.println("Already recording");
    return false;
  }
  
  currentFileName = generateFileName();
  
  dataFile = SD.open(currentFileName.c_str(), FILE_WRITE);
  if (!dataFile) {
    Serial.println("ERROR: Failed to create file");
    return false;
  }
  
  dataFile.println("Timestamp,X,Y,Z");
  dataFile.flush();
  
  bufferIndex = 0;
  totalSamples = 0;
  sessionStartTime = millis();
  lastFlushTime = sessionStartTime;
  isRecording = true;
  
  Serial.println(" Recording started!");
  
  return true;
}

void flushBufferToSD() {
  if (bufferIndex == 0) return;
  
  Serial.printf("Flushing %d samples... ", bufferIndex);
  
  for (uint32_t i = 0; i < bufferIndex; i++) {
    dataFile.printf("%u,%d,%d,%d\n",
                    psramBuffer[i].timestamp,
                    psramBuffer[i].x,
                    psramBuffer[i].y,
                    psramBuffer[i].z);
  }
  
  dataFile.flush();
  
  bufferIndex = 0;
  lastFlushTime = millis();
}

void stopRecording() {
  if (!isRecording) {
    return;
  }
  
  Serial.println("\n--- STOPPING RECORDING ---");
  
  flushBufferToSD();
  dataFile.close();
  
  float actualDuration = (millis() - sessionStartTime) / 1000.0;
  float expectedDuration = totalSamples / 125.0;  // Expected duration at 125Hz
  float readRate = totalSamples / actualDuration;
  
  Serial.printf("  Total samples: %u\n", totalSamples);
  Serial.printf("  Expected duration (at 125Hz): %.1f seconds\n", expectedDuration);
  Serial.printf("  Actual duration: %.1f seconds\n", actualDuration);
  
  isRecording = false;
  
  Serial.println("\n Data saved!");
}

void processAccelMagnitude(int16_t y, int16_t z, uint32_t timestamp) {
  float fy = (float)y;
  float fz = (float)z;
  float mag = sqrtf(fy * fy + fz * fz);  // magnitude of Y/Z axes

  if (magCount < MAG_WINDOW_SIZE) {
    magSum += mag;
    magWindow[magIndex] = mag;
    magCount++;
  } else {
    magSum -= magWindow[magIndex];
    magSum += mag;
    magWindow[magIndex] = mag;
  }

  magIndex++;
  if (magIndex >= MAG_WINDOW_SIZE) {
    magIndex = 0;
  }

  float filteredMag = magSum / magCount;

   // Store filtered magnitude in history buffer
  filteredHistory[filteredIndex] = filteredMag;
  filteredIndex++;
  if (filteredIndex >= FILTER_HISTORY_SIZE) {
    filteredIndex = 0;
  }
  if (filteredCount < FILTER_HISTORY_SIZE) {
    filteredCount++;
  }

  // Spike detection on filtered magnitude
  if (filteredMag > 300.0f) {
    Serial.printf("Spike detected at %u ms, filtered |YZ| = %.2f\n", timestamp, filteredMag);

    // Run model on last 850 filtered samples if available
    if (filteredCount >= INFERENCE_WINDOW_SIZE) {
      runInferenceOnLastWindow(timestamp);
    } else {
      Serial.println("Not enough filtered samples for inference yet");
    }
  }
}

void runInferenceOnLastWindow(uint32_t timestamp) {
  if (tflInterpreter == nullptr || tflInput == nullptr || tflOutput == nullptr) {
    Serial.println("TFLite not initialized, skipping inference");
    return;
  }

  int inputLen = tflInput->bytes / sizeof(float);
  if (inputLen < INFERENCE_WINDOW_SIZE) {
    Serial.printf("Model input too small (%d) for %d-sample window\n", inputLen, INFERENCE_WINDOW_SIZE);
    return;
  }

  float* inputData = tflInput->data.f;

  int start = filteredIndex - INFERENCE_WINDOW_SIZE;
  if (start < 0) {
    start += FILTER_HISTORY_SIZE;
  }

  for (int i = 0; i < INFERENCE_WINDOW_SIZE; i++) {
    int idx = (start + i) % FILTER_HISTORY_SIZE;
    inputData[i] = filteredHistory[idx];
  }

  for (int i = INFERENCE_WINDOW_SIZE; i < inputLen; i++) {
    inputData[i] = 0.0f;
  }

  TfLiteStatus invokeStatus = tflInterpreter->Invoke();
  if (invokeStatus != kTfLiteOk) {
    Serial.println("Inference failed");
    return;
  }

  int outputLen = tflOutput->bytes / sizeof(float);
  float* outputData = tflOutput->data.f;

  Serial.printf("Inference at %u ms, output:", timestamp);
  for (int i = 0; i < outputLen; i++) {
    Serial.print(" ");
    Serial.print(outputData[i], 4);
  }
  Serial.println();
}

void addSample(int16_t x, int16_t y, int16_t z) {
  if (!isRecording) return;
  
  // Calculate timestamp based on sample count and known sample rate (125Hz)
  // This gives accurate timestamps even when reading FIFO in bursts
  uint32_t timestamp = (totalSamples * 1000) / 125;  // milliseconds = (samples * 1000ms) / 125 samples/sec
  
  psramBuffer[bufferIndex].timestamp = timestamp;
  psramBuffer[bufferIndex].x = x;
  psramBuffer[bufferIndex].y = y;
  psramBuffer[bufferIndex].z = z;
  
  bufferIndex++;
  totalSamples++;
  
  if (totalSamples % 1000 == 0) {
    float duration = (millis() - sessionStartTime) / 1000.0;
    float actualSampleRate = totalSamples / duration;
    float expectedDuration = totalSamples / 125.0;  // What duration should be at 125Hz
    Serial.printf("Recording: %u samples (%.1f sec actual, %.1f sec expected @ 125Hz)\n", 
                  totalSamples, duration, expectedDuration);
  }
  
  if (bufferIndex >= BUFFER_SIZE) {
    flushBufferToSD();
  }
  
  if (millis() - lastFlushTime >= FLUSH_INTERVAL_MS) {
    flushBufferToSD();
  }

  // Process accelerometer magnitude on Y and Z axes
  processAccelMagnitude(y, z, timestamp);
}

void checkButtons() {
  static int lastStartState = HIGH;
  static int lastStopState = HIGH;
  static unsigned long lastStartPress = 0;
  static unsigned long lastStopPress = 0;
  
  int startState = digitalRead(START_BUTTON_PIN);
  int stopState = digitalRead(STOP_BUTTON_PIN);
  
  if (startState == LOW && lastStartState == HIGH) {
    if (millis() - lastStartPress > 500) {
      startNewSession();
      lastStartPress = millis();
    }
  }
  
  if (stopState == LOW && lastStopState == HIGH) {
    if (millis() - lastStopPress > 500) {
      stopRecording();
      lastStopPress = millis();
    }
  }
  
  lastStartState = startState;
  lastStopState = stopState;
}

void setup() {
  Serial.begin(115200);
  delay(2000);  // Give time for serial to initialize

  Serial.println("\nRowing Session Logger (with |YZ| magnitude filter)");

  // Setup Buttons
  pinMode(START_BUTTON_PIN, INPUT_PULLUP);
  pinMode(STOP_BUTTON_PIN, INPUT_PULLUP);
  
  if (digitalRead(START_BUTTON_PIN) == LOW || digitalRead(STOP_BUTTON_PIN) == LOW) {
    Serial.println("\nWARNING: A button appears to be pressed at startup");
    Serial.println("This might indicate a wiring issue.");
  }

  // Initialize PSRAM
  if (!initPSRAM()) {
    Serial.println("\nFATAL: Cannot continue without PSRAM");
    while(1);
  }

  // Initialize TensorFlow Lite Micro
  if (!initTFLite()) {
    Serial.println("\nFATAL: Cannot continue without TensorFlow Lite Micro");
    while(1);
  }

  // Initialize SD Card
  if (!initSD()) {
    Serial.println("\nFATAL: Cannot continue without SD card");
    while(1);
  }

  // Initialize I2C
  Serial.println("\nSensor Initialization");
  Wire.begin(I2C_SDA, I2C_SCL); 
  Wire.setClock(400000); 

  writeReg(REG_RESET, RESET_CMD);
  delay(500); 

  uint8_t who = readReg(REG_WHO_AM_I);
  Serial.printf("Sensor WHO_AM_I: 0x%02X ", who);
  if (who == 0x05) {
  } else {
    Serial.println("Sensor not found!");
    while(1);
  }

  writeReg(REG_CTRL1, 0x40);
  writeReg(REG_CTRL2, ACC_ODR_125HZ | ACC_RANGE_4G | ACC_HI_RES);
  writeReg(REG_FIFO_CTRL, 0x0D);
  writeReg(REG_CTRL7, ACC_ENABLE);
  delay(100);

  Serial.println("Sensor configured: 125Hz, ±4g");  
  Serial.println("\n--- Press START button to begin ---");
}

void loop() {
  // Check buttons
  checkButtons();

  // Read sensor data if recording
  if (isRecording) {
    uint8_t fifo_lsb = readReg(REG_FIFO_SMPL);
    uint8_t fifo_status = readReg(REG_FIFO_STATUS);
    uint16_t fifo_bytes = fifo_lsb | ((fifo_status & 0x03) << 8);

    if (fifo_bytes >= 6) {
      writeReg(REG_CTRL1, 0x00); 
      writeReg(REG_CTRL9, CMD_REQ_FIFO);

      uint32_t startTime = millis();
      bool ready = false;
      while (millis() - startTime < 10) {
        uint8_t statusInt = readReg(REG_STATUSINT);
        uint8_t fifoCtrl = readReg(REG_FIFO_CTRL);
        
        if ((statusInt & 0x80) && (fifoCtrl & 0x80)) {
          ready = true;
          break;
        }
      }

      if (ready) {
        while (fifo_bytes >= 6) {
          int bytesToRead = (fifo_bytes > 96) ? 96 : fifo_bytes;
          bytesToRead = (bytesToRead / 6) * 6;

          Wire.beginTransmission(QMI8658_ADDR);
          Wire.write(REG_FIFO_DATA);
          Wire.endTransmission(false);
          
          if (Wire.requestFrom((uint8_t)QMI8658_ADDR, (uint8_t)bytesToRead) == bytesToRead) {
            for (int i = 0; i < bytesToRead; i += 6) {
              int16_t ax = (int16_t)(Wire.read() | (Wire.read() << 8));
              int16_t ay = (int16_t)(Wire.read() | (Wire.read() << 8));
              int16_t az = (int16_t)(Wire.read() | (Wire.read() << 8));
              
              if (ax != -7968 || ay != -7968) {
                addSample(ax, ay, az);
              }
            }
          }
          fifo_bytes -= bytesToRead;
        }
      }

      writeReg(REG_CTRL1, 0x40); 
      writeReg(REG_FIFO_CTRL, 0x0D); 
    }
  }

  delay(5);
}

