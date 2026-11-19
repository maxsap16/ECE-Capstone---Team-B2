// logger.ino -- STAGE 5: one CSV line per log period. Same columns in every file.
// Guesses and state are printed as numbers (the codes from config.h) so they line up
// with the label numbers the PC script adds: 0 REST, 1 OPEN, 2 FIST, 3 PINCH, 4 POINT,
// 7 INVALID, and for fsm_state 5 = FAULT.

void loggerHeader() {
  Serial.println(F("ms,flexor,extensor,thumb,index,rule_guess,nn_guess,agreed,fsm_state,"
                   "flex0,flex1,flex2,flex3,flex4,fsr0,fsr1,fsr2,fsr3,fsr4,label"));
}

void loggerRow(unsigned long ms, uint8_t rulePattern, uint8_t nnPattern, bool agreed, uint8_t state) {
  Serial.print(ms);

  for (uint8_t ch = 0; ch < NUM_EMG; ch++) {     // filtered EMG values
    Serial.print(',');
    Serial.print(emgFiltered(ch));
  }

  Serial.print(',');  Serial.print(rulePattern);
  Serial.print(',');
#if USE_NN
  Serial.print(nnPattern);                        // empty when the network is off
#endif
  Serial.print(',');  Serial.print(agreed ? 1 : 0);
  Serial.print(',');  Serial.print(state);

  for (uint8_t f = 0; f < NUM_FINGERS; f++) {     // flex: empty when not wired
    Serial.print(',');
    int v = flexValue(f);
    if (v >= 0) Serial.print(v);
  }
  for (uint8_t f = 0; f < NUM_FINGERS; f++) {     // FSR: empty when not wired
    Serial.print(',');
    int v = fsrValue(f);
    if (v >= 0) Serial.print(v);
  }

  Serial.println(',');                            // empty label column; the PC script fills it in
}

// Lines that start with EVENT are ignored by the PC scripts.
void loggerEvent(const char* text) {
  Serial.print(F("EVENT "));
  Serial.println(text);
}