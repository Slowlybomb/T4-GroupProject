// QMI8658C accelerometer driver and data processing
//
// Reads Y/Z data, removes gravity, smooths the motion, and buffers data for the neural network.

#pragma once
#ifndef DEBUG_GONDOLIER
#define DEBUG_GONDOLIER 0
#endif
#include <Wire.h>
#include <math.h>

// I2C & register addresses
#define QMI8658_ADDR    0x6B
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

#define RESET_CMD       0xB0
#define ACC_ENABLE      0x01
#define ACC_ODR_125HZ   0x04
#define ACC_RANGE_4G    0x01
#define ACC_HI_RES      0x10
#define CMD_REQ_FIFO    0x05

// buffer size for inference
#define MODEL_INPUT_LEN 850

// Ring buffer holding the last 850 samples for the model
static float* _inferenceBuffer = nullptr;
static int    _infBufHead  = 0;
static int    _infBufCount = 0;

//variables for high pass filter, this filters out the changes due to gravity (the boat tilting along its axis)
#define GRAVITY_WINDOW  500
static float* _gravBuf = nullptr;
static float  _gravSum  = 0.0f;
static int    _gravHead = 0;
static bool   _gravFull = false;

// variables for low pass, this is to remove noise on the accelerometer
#define MOTION_WINDOW   100
static float* _motBuf = nullptr;
static float  _motSum  = 0.0f;
static int    _motHead = 0;
static bool   _motFull = false;

// Normalise
static float _normMean  = 0.0f;
static float _normStd   = 1.0f;

// I2C
inline void accel_writeReg(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(QMI8658_ADDR);
  Wire.write(reg);
  Wire.write(val);
  Wire.endTransmission();
}

inline uint8_t accel_readReg(uint8_t reg) {
  Wire.beginTransmission(QMI8658_ADDR);
  Wire.write(reg);
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)QMI8658_ADDR, (uint8_t)1);
  return Wire.read();
}

// Initialisation

// sets up i2c and accelerometer writing to the register to control frequency and range
bool accel_init(uint8_t sda, uint8_t scl) {
  Wire.begin(sda, scl);
  Wire.setClock(400000);

  accel_writeReg(REG_RESET, RESET_CMD);
  delay(500);

  uint8_t who = accel_readReg(REG_WHO_AM_I);
  if (who != 0x05) {
    Serial.printf("[ACCEL] WHO_AM_I mismatch: 0x%02X\n", who);
    return false;
  }

  accel_writeReg(REG_CTRL1, 0x40);
  accel_writeReg(REG_CTRL2, ACC_ODR_125HZ | ACC_RANGE_4G | ACC_HI_RES);
  accel_writeReg(REG_FIFO_CTRL, 0x0D);
  accel_writeReg(REG_CTRL7, ACC_ENABLE);
  delay(100);

#if DEBUG_GONDOLIER
  Serial.println("[ACCEL] QMI8658C ready: 125 Hz, ±4 g");
#endif

  // Allocate all large buffers in PSRAM to keep DRAM free - i nearly ripped my hair out trying to figure out this shit xoxo
  _gravBuf = (float*)ps_malloc(GRAVITY_WINDOW * sizeof(float));
  _motBuf  = (float*)ps_malloc(MOTION_WINDOW  * sizeof(float));
  _inferenceBuffer = (float*)ps_malloc(MODEL_INPUT_LEN * sizeof(float));

  if (!_gravBuf || !_motBuf || !_inferenceBuffer) {
    Serial.println("[ACCEL] FATAL: PSRAM allocation failed for signal buffers");
    return false;
  }

  memset(_gravBuf,         0, GRAVITY_WINDOW  * sizeof(float));
  memset(_motBuf,          0, MOTION_WINDOW   * sizeof(float));
  memset(_inferenceBuffer, 0, MODEL_INPUT_LEN * sizeof(float));

  return true;
}

// data processing
// magnitude, remove gravity, smooth, normalise buffer.
bool accel_processSample(int16_t ay, int16_t az, float* out) {
  float mag = sqrtf((float)ay * ay + (float)az * az); 

// high pass filter
  _gravSum -= _gravBuf[_gravHead];
  _gravBuf[_gravHead] = mag;
  _gravSum += mag;
  _gravHead = (_gravHead + 1) % GRAVITY_WINDOW;
  if (_gravHead == 0) _gravFull = true;

  int gravCount = _gravFull ? GRAVITY_WINDOW : _gravHead;
  float gravity = _gravSum / (float)gravCount;

  float motion = mag - gravity;

//low pass filter
  _motSum -= _motBuf[_motHead];
  _motBuf[_motHead] = motion;
  _motSum += motion;
  _motHead = (_motHead + 1) % MOTION_WINDOW;
  if (_motHead == 0) _motFull = true;

  int motCount = _motFull ? MOTION_WINDOW : _motHead;
  float motionAvg = _motSum / (float)motCount;

  // Normalise
  float normalised = (_normStd > 1e-6f)
                     ? (motionAvg - _normMean) / _normStd
                     : 0.0f;

  // Add to the buffer 
  _inferenceBuffer[_infBufHead] = normalised;
  _infBufHead = (_infBufHead + 1) % MODEL_INPUT_LEN;
  if (_infBufCount < MODEL_INPUT_LEN) _infBufCount++;

  if (out) *out = normalised;

  return _motFull;
}

// Copies the last 850 samples into dest, oldest first. Returns false if we haven't collected enough data yet.
bool accel_getModelInput(float* dest) {
  if (_infBufCount < MODEL_INPUT_LEN) return false;

  int start = _infBufHead;
  for (int i = 0; i < MODEL_INPUT_LEN; i++) {
    dest[i] = _inferenceBuffer[(start + i) % MODEL_INPUT_LEN];
  }
  return true;
}

// FIFO drain

// Reads accelerometer's FIFO and processes sample.
void accel_drainFIFO() {
  uint8_t fifo_lsb    = accel_readReg(REG_FIFO_SMPL);
  uint8_t fifo_status = accel_readReg(REG_FIFO_STATUS);
  uint16_t fifo_bytes = fifo_lsb | ((fifo_status & 0x03) << 8);

  if (fifo_bytes < 6) return;

  // Latch the FIFO before we read
  accel_writeReg(REG_CTRL1, 0x00);
  accel_writeReg(REG_CTRL9, CMD_REQ_FIFO);

  // Wait for it to be ready (up to 10ms)
  uint32_t t0 = millis();
  bool ready = false;
  while (millis() - t0 < 10) {
    if ((accel_readReg(REG_STATUSINT) & 0x80) &&
        (accel_readReg(REG_FIFO_CTRL)  & 0x80)) {
      ready = true;
      break;
    }
  }

  if (ready) {
    while (fifo_bytes >= 6) {
      int toRead = min((int)fifo_bytes, 96);
      toRead = (toRead / 6) * 6;

      Wire.beginTransmission(QMI8658_ADDR);
      Wire.write(REG_FIFO_DATA);
      Wire.endTransmission(false);

      if (Wire.requestFrom((uint8_t)QMI8658_ADDR, (uint8_t)toRead) == toRead) {
        for (int i = 0; i < toRead; i += 6) {
          int16_t ax = (int16_t)(Wire.read() | (Wire.read() << 8)); //we later discard the x data, it is not used
          int16_t ay = (int16_t)(Wire.read() | (Wire.read() << 8));
          int16_t az = (int16_t)(Wire.read() | (Wire.read() << 8));

          if (ax == -7968 && ay == -7968) continue;  // skip FIFO sentinel

          accel_processSample(ay, az, nullptr);
        }
      }
      fifo_bytes -= toRead;
    }
  }

  // Turn FIFO streaming back on
  accel_writeReg(REG_CTRL1, 0x40);
  accel_writeReg(REG_FIFO_CTRL, 0x0D);
}
