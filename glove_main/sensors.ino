// sensors.ino -- STAGE 1: read the EMG channels, filter them, decide which muscles are "on".
// Does not decide gestures. Gesture decisions happen in decoders.ino.

//might become obsolete with max's code

int  avgBuf[NUM_EMG][AVG_N];   // last AVG_N readings per channel
long avgSum[NUM_EMG];          // running sum, so the average is cheap
int  avgIdx[NUM_EMG];          // where the next reading goes in the buffer
int  filtered[NUM_EMG];        // filtered value, 0..1023
bool onFlag[NUM_EMG];          // is this muscle "on" right now

// Read a pin twice and keep the second reading. The first read after the Arduino's ADC
// switches pins can carry leftover charge from the previous channel (possible crosstalk source).
int readEmg(uint8_t ch) {
  analogRead(EMG_PINS[ch]);              // throwaway
  return analogRead(EMG_PINS[ch]);
}

void sensorsBegin() {
  for (uint8_t ch = 0; ch < NUM_EMG; ch++) {
    int first = readEmg(ch);
    for (int i = 0; i < AVG_N; i++) avgBuf[ch][i] = first;   // start the average at the first reading
    avgSum[ch] = (long)first * AVG_N;
    avgIdx[ch] = 0;
    filtered[ch] = first;
    onFlag[ch] = false;
  }
}

void sensorsUpdate() {
  for (uint8_t ch = 0; ch < NUM_EMG; ch++) {
    int raw = readEmg(ch);

    // moving average over the last AVG_N readings
    avgSum[ch] -= avgBuf[ch][avgIdx[ch]];
    avgBuf[ch][avgIdx[ch]] = raw;
    avgSum[ch] += raw;
    avgIdx[ch] = (avgIdx[ch] + 1) % AVG_N;
    filtered[ch] = (int)(avgSum[ch] / AVG_N);

    // hysteresis: turns ON above THR_ON, OFF only below THR_OFF
    if (onFlag[ch]) { if (filtered[ch] < THR_OFF[ch]) onFlag[ch] = false; }
    else            { if (filtered[ch] >= THR_ON[ch]) onFlag[ch] = true;  }
  }
}

int  emgFiltered(uint8_t ch) { return filtered[ch]; }
bool emgOn(uint8_t ch)       { return onFlag[ch]; }

// Not wired yet: return -1 so the log can leave the column empty.
int flexValue(uint8_t finger) {
#if USE_FLEX
  return analogRead(FLEX_PINS[finger]);
#else
  return -1;
#endif
}
int fsrValue(uint8_t finger) {
#if USE_FSR
  return analogRead(FSR_PINS[finger]);
#else
  return -1;
#endif
}