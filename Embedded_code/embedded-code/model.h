// Neural network inference for stroke detection
//
// Loads model.tflite and runs it on the accelerometer data. Output is a score
// 0–1; main.ino counts a stroke when that score crosses above 0.5.
//

#pragma once
#ifndef DEBUG_GONDOLIER
#define DEBUG_GONDOLIER 0
#endif

// TensorFlow Lite Micro
#include <TensorFlowLite_ESP32.h>
#include "tensorflow/lite/micro/micro_mutable_op_resolver.h"
#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/micro_error_reporter.h"
#include "tensorflow/lite/schema/schema_generated.h"

#include "model_data.h"
#include "accelerometer.h"

//  TFLite arena
// load model into psram - this is huge - i hate it
#define TFLITE_ARENA_SIZE (330 * 1024)
static uint8_t* _tensorArena = nullptr;

static float* _modelInputBuf = nullptr;

// some stuff the internet says will make it use less ram. idk???
using MyOpResolver = tflite::MicroMutableOpResolver<20>;
static MyOpResolver _resolver;

// TFLite runtime state
static tflite::MicroErrorReporter  _errorReporter;
static const tflite::Model*        _tfModel      = nullptr;
static tflite::MicroInterpreter*   _interpreter  = nullptr;
static TfLiteTensor*               _inputTensor  = nullptr;
static TfLiteTensor*               _outputTensor = nullptr;
static bool                        _modelReady   = false;

// Initialisation

// Allocates memory, loads the model, sets up the interpreter.
bool model_init() {
  // Try PSRAM first, then revert to DRAM
  _tensorArena = (uint8_t*)( psramFound()
    ? ps_malloc(TFLITE_ARENA_SIZE)
    :    malloc(TFLITE_ARENA_SIZE) );
  if (!_tensorArena) {
    Serial.println("[MODEL] FATAL: allocation for tensor arena failed");
    return false;
  }
#if DEBUG_GONDOLIER
  Serial.printf("[MODEL] Arena in %s\n", psramFound() ? "PSRAM" : "heap");
#endif

  _modelInputBuf = (float*)(psramFound() ? ps_malloc(MODEL_INPUT_LEN * sizeof(float))
                                         : malloc(MODEL_INPUT_LEN * sizeof(float)));
  if (!_modelInputBuf) {
    Serial.println("[MODEL] FATAL: model input buffer alloc failed");
    return false;
  }

  // Register ops used by the model
  _resolver.AddExpandDims();
  _resolver.AddConv2D();
  _resolver.AddDepthwiseConv2D();
  _resolver.AddFullyConnected();
  _resolver.AddRelu();
  _resolver.AddRelu6();
  _resolver.AddLogistic();
  _resolver.AddSoftmax();
  _resolver.AddReshape();
  _resolver.AddMaxPool2D();
  _resolver.AddMean();
  _resolver.AddUnidirectionalSequenceLSTM();
  _resolver.AddStridedSlice();
  _resolver.AddPad();
  _resolver.AddAdd();
  _resolver.AddMul();
  _resolver.AddQuantize();
  _resolver.AddDequantize();
  _resolver.AddShape();
  _resolver.AddSqueeze();

  _tfModel = tflite::GetModel(model_tflite);
  if (_tfModel->version() != TFLITE_SCHEMA_VERSION) {
    Serial.printf("[MODEL] Schema version mismatch: got %d, expected %d\n",
                  _tfModel->version(), TFLITE_SCHEMA_VERSION);
    return false;
  }

  _interpreter = new tflite::MicroInterpreter(
      _tfModel, _resolver, _tensorArena, TFLITE_ARENA_SIZE, &_errorReporter);

  if (_interpreter->AllocateTensors() != kTfLiteOk) {
    Serial.println("[MODEL] AllocateTensors() failed — increase TFLITE_ARENA_SIZE");
    return false;
  }

  _inputTensor  = _interpreter->input(0);
  _outputTensor = _interpreter->output(0);

#if DEBUG_GONDOLIER
  Serial.printf("[MODEL] Input  shape: [%d, %d]\n",
                _inputTensor->dims->data[0],
                _inputTensor->dims->data[1]);
  Serial.printf("[MODEL] Output shape: [%d, %d]\n",
                _outputTensor->dims->data[0],
                _outputTensor->dims->data[1]);
  Serial.println("[MODEL] Ready.");
#endif
  _modelReady = true;
  return true;
}

// Inference
float model_infer(const float* inputData) {
  if (!_interpreter) return -1.0f;

  // Copy processed window into input tensor
  for (int i = 0; i < MODEL_INPUT_LEN; i++) {
    _inputTensor->data.f[i] = inputData[i];
  }

  if (_interpreter->Invoke() != kTfLiteOk) {
    Serial.println("[MODEL] Invoke() failed");
    return -1.0f;
  }

  return _outputTensor->data.f[0];
}

// takes the latest 850 samples from the accelerometer and runs inference.
float model_inferFromAccel() {
  if (!_modelReady || !_modelInputBuf || !accel_getModelInput(_modelInputBuf))
    return -1.0f;
  return model_infer(_modelInputBuf);
}
