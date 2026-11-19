// servo_out.ino -- STAGE 4: FSM state -> servo positions. The pose table is the only place
// servo values live (they change next semester).
#include <Servo.h>

//                          SERVO 0  SERVO 1    (percent of travel; PLACEHOLDERS)
const int POSE_PCT[6][NUM_SERVOS] = {
  /* REST  */ {  50,  50 },
  /* OPEN  */ {   0,   0 },
  /* FIST  */ { 100, 100 },
  /* PINCH */ {  50,  50 },   // TODO: set once the real servo layout is known
  /* POINT */ {  50,  50 },   // TODO
  /* FAULT */ {  50,  50 },   // servos are detached in FAULT
};

Servo servos[NUM_SERVOS];
int  appliedPct[NUM_SERVOS];     // where each servo is right now (percent)
bool attached = false;

int pctToUs(int pct) {
  int us = map(pct, 0, 100, SERVO_OPEN_US, SERVO_CLOSED_US);
  return constrain(us, 1000, 2000);              // safe range
}

void servoBegin() {
  for (int i = 0; i < NUM_SERVOS; i++) appliedPct[i] = 50;
#if USE_SERVO
  for (int i = 0; i < NUM_SERVOS; i++) { servos[i].attach(SERVO_PINS[i]); servos[i].writeMicroseconds(pctToUs(appliedPct[i])); }
  attached = true;
#endif
}

void servoUpdate(uint8_t state) {
#if USE_SERVO
  if (state == S_FAULT) {                         // FAULT: let go
    if (attached) { for (int i = 0; i < NUM_SERVOS; i++) servos[i].detach(); attached = false; }
    return;
  }
  if (!attached) {                                // coming back from FAULT
    for (int i = 0; i < NUM_SERVOS; i++) { servos[i].attach(SERVO_PINS[i]); servos[i].writeMicroseconds(pctToUs(appliedPct[i])); }
    attached = true;
  }
#endif
  for (int i = 0; i < NUM_SERVOS; i++) {          // ramp toward the pose
    int target = POSE_PCT[state][i];
    if (appliedPct[i] < target)      appliedPct[i] = min(appliedPct[i] + SLEW_PCT, target);
    else if (appliedPct[i] > target) appliedPct[i] = max(appliedPct[i] - SLEW_PCT, target);
#if USE_SERVO
    servos[i].writeMicroseconds(pctToUs(appliedPct[i]));
#endif
  }
}

int servoPulseUs(uint8_t servo) { return pctToUs(appliedPct[servo]); }