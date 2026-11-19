// glove_main.ino -- ties the stages together. Keep it short: it only calls the other tabs.
// Per frame: sensors -> rule decoder (+ network if USE_NN) -> FSM -> servos -> log

//what happens every 5 mn (one frame):
// 1) sensors = read the four muscle sensors and filter them
// 2) decoders = turn the muscle sigs into a gesture guess (use neural network too is use_nn = true)
// 3) fsm = your control logic and safety decide what the glove actually does
// 4) servos = move the servos to match
// 5) log = print one line of data (every 50 ms)

#include "config.h"

unsigned long lastFrame = 0, lastLog = 0;

void setup() {
  Serial.begin(115200); //usb connection
  sensorsBegin();
  fsmBegin();
  servoBegin();
#if USE_NN
  nnSelfTest();
#endif
  loggerHeader(); //print column names as the first line of the CSV
  // TODO: serial commands (e.g. 'c' = calibrate, 'k' = software kill)
  //could add later if want but not needed
}

void loop() {
  unsigned long now = millis(); //ms since power up
  if (now - lastFrame < FRAME_MS) return; //if not 5 ms skip this pass
  lastFrame = now; //remember when this frame started
  bool settled = (now >= SETTLE_MS); //false for firt second so glove stays rest 

// ------------------ 1) Sensors -------------------
  sensorsUpdate(); //read all channels filter them work out which muscles are on

// ------------------ 2) Decoders: two opinions on what gesture is ------------------------
//rule decoder looks at which of four muscles are on and applies the ordered rules 
  uint8_t rulePattern = ruleDecode(emgOn(CH_FLEXOR), emgOn(CH_EXTENSOR), emgOn(CH_THUMB), emgOn(CH_INDEX));

//the netowkr decoder only exists when use_nn is true otherwise it just has no opinion
  uint8_t nnPattern = P_INVALID;
#if USE_NN
  int f[NUM_EMG]; //the filtered values 
  for (int i = 0; i < NUM_EMG; i++) f[i] = emgFiltered(i);
  nnPattern = nnDecode(f); //the networks guess
#endif

// ------------- 3) fsm -------------------------
//gets both guesses and check if they agree and makes sure the pattern holds and then applies safety check and updates state
  fsmStep(rulePattern, nnPattern, settled);

// ---------------- 4) servos ------------------------
  servoUpdate(fsmState());

// ----------------------- 5) log print one csv line ----------------------------------
#if LOG_CSV
  if (now - lastLog >= LOG_PERIOD_MS) { 
    lastLog = now;
    loggerRow(now, rulePattern, nnPattern, fsmAgreed(), fsmState()); 
  }
#endif
}
