// config.h -- all settings and shared names. Change numbers and switches here only.
#pragma once
#include <Arduino.h>

// ---------- Build options (change, then re-upload) ----------
#define USE_NN          false  // true once weights exist: network must agree with the rules
#define USE_SERVO       false  // false = no servos connected
#define USE_FLEX        false  // flex sensors not wired yet
#define USE_FSR         false  // FSRs not wired yet
#define EMG_FROM_SERIAL false  // not built yet; leave false
#define LOG_CSV         true   // turn off for latency (scope) tests

// ---------- Gesture codes ----------
enum Pattern  : uint8_t { P_REST = 0, P_OPEN = 1, P_FIST = 2, P_PINCH = 3, P_POINT = 4, P_INVALID = 7 };
enum FsmState : uint8_t { S_REST = 0, S_OPEN = 1, S_FIST = 2, S_PINCH = 3, S_POINT = 4, S_FAULT = 5 };

// ---------- EMG channels (order = log column order) ----------
enum EmgChannel : uint8_t { CH_FLEXOR, CH_EXTENSOR, CH_THUMB, CH_INDEX, NUM_EMG };
const int EMG_PINS[NUM_EMG] = { A0, A1, A2, A3 };

// ---------- Other sensors (only used when enabled) ----------
const int NUM_FINGERS = 5;
const int FLEX_PINS[NUM_FINGERS] = { A4, A5, A6, A7, A8 };       // TODO when wired
const int FSR_PINS[NUM_FINGERS]  = { A9, A10, A11, A12, A13 };   // TODO when wired

// ---------- Servos ----------
const int NUM_SERVOS = 2;
const int SERVO_PINS[NUM_SERVOS] = { 2, 3 };
const int KILL_PIN = 4;                      // button to GND: held = FAULT
const int SERVO_OPEN_US   = 1000;            // pulse width at 0 %
const int SERVO_CLOSED_US = 2000;            // pulse width at 100 %
const int SLEW_PCT        = 2;               // % of travel per frame (100 = no ramp)

// ---------- Timing ----------
const unsigned long FRAME_MS      = 5;
const unsigned long LOG_PERIOD_MS = 50;
const unsigned long SETTLE_MS     = 1000;    // hold REST after power-up
const int PERSIST_FRAMES = 2;                // frames a pattern must hold (2 x 5 ms = 10 ms)
const int AVG_N = 4;                         // filter length

// ---------- Safety timing (from Max's design) ----------
const unsigned long COCONTRACT_MS = 1000;    // flexor + extensor both on this long = FAULT
const unsigned long CLEAR_MS      = 500;     // must stay relaxed this long to leave FAULT

// ---------- Thresholds (10-bit counts, one per channel) ----------
// ON above THR_ON, OFF below THR_OFF; the gap stops flicker.
// Flexor/extensor come from the Nov 4 test. Thumb/index are placeholders: retune after placement.
const int THR_ON[NUM_EMG]  = { 260, 200, 200, 200 };
const int THR_OFF[NUM_EMG] = { 160, 120, 120, 120 };