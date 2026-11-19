// fsm.ino -- STAGE 3: control logic + safety. Table-driven: the behavior is the TABLE below.

const uint8_t S_ANY = 255;   // "from any state"
enum Cond : uint8_t { C_FAULT, C_CLEARED, C_ENTER_OPEN, C_ENTER_FIST, C_ENTER_PINCH, C_ENTER_POINT, C_LEAVE };
struct Row { uint8_t from; uint8_t cond; uint8_t to; };

// Checked top to bottom, FIRST match wins, so row order = priority.
// There is no row from one gesture straight to another: you must pass through REST.
const Row TABLE[] = {
  { S_ANY,   C_FAULT,       S_FAULT },   // safety beats everything
  { S_FAULT, C_CLEARED,     S_REST  },   // leave FAULT only when relaxed long enough and kill released
  { S_REST,  C_ENTER_OPEN,  S_OPEN  },
  { S_REST,  C_ENTER_FIST,  S_FIST  },
  { S_REST,  C_ENTER_PINCH, S_PINCH },
  { S_REST,  C_ENTER_POINT, S_POINT },
  { S_OPEN,  C_LEAVE,       S_REST  },
  { S_FIST,  C_LEAVE,       S_REST  },
  { S_PINCH, C_LEAVE,       S_REST  },
  { S_POINT, C_LEAVE,       S_REST  },
};
const int NUM_ROWS = sizeof(TABLE) / sizeof(TABLE[0]);

// ---- State the engine keeps between frames ----
uint8_t fsmCur = S_REST;
uint8_t candidate = P_INVALID;     // what the decoders currently say (after the agreement rule)
int     candCount = 0;             // how many frames in a row the candidate has been the same
bool    agreedNow = true;
bool    faultNow = false;          // a fault trigger is present
bool    clearedNow = false;        // relaxed long enough and kill released
unsigned long coStart = 0;      bool coActive = false;       // co-contraction timer
unsigned long relaxedStart = 0; bool relaxedActive = false;  // relaxed timer

bool killPressed() { return digitalRead(KILL_PIN) == LOW; }

bool allRelaxed() {
  for (uint8_t ch = 0; ch < NUM_EMG; ch++) if (emgOn(ch)) return false;
  return true;
}

bool condTrue(uint8_t c) {
  bool held = (candCount >= PERSIST_FRAMES);
  switch (c) {
    case C_FAULT:       return faultNow;
    case C_CLEARED:     return clearedNow;
    case C_ENTER_OPEN:  return held && candidate == P_OPEN;
    case C_ENTER_FIST:  return held && candidate == P_FIST;
    case C_ENTER_PINCH: return held && candidate == P_PINCH;
    case C_ENTER_POINT: return held && candidate == P_POINT;
    case C_LEAVE:       return held && candidate == P_REST;
  }
  return false;
}

void fsmBegin() {
  pinMode(KILL_PIN, INPUT_PULLUP);   // button to GND; unpressed reads HIGH
  fsmCur = S_REST;
}

void fsmStep(uint8_t rulePattern, uint8_t nnPattern, bool settled) {
  unsigned long now = millis();

  // ---- Agreement rule ----
  // Leave to REST if EITHER decoder says REST. Enter a gesture only if BOTH say the same thing.
  bool nnRest = USE_NN && (nnPattern == P_REST);
  uint8_t cand;
  if (rulePattern == P_REST || nnRest) cand = P_REST;
  else if (USE_NN)                     cand = (rulePattern == nnPattern) ? rulePattern : P_INVALID;
  else                                 cand = rulePattern;
  agreedNow = !USE_NN || (rulePattern == nnPattern);

  // ---- Persistence counter ----
  if (cand == candidate) { if (candCount < 1000) candCount++; }
  else                   { candidate = cand; candCount = 1; }

  // ---- Safety ----
  bool both = emgOn(CH_FLEXOR) && emgOn(CH_EXTENSOR);
  if (!both) coActive = false;
  else if (!coActive) { coActive = true; coStart = now; }
  bool coFault = coActive && (now - coStart >= COCONTRACT_MS);
  faultNow = killPressed() || coFault;
  // TODO: FSR force limit and ADC watchdog, once those sensors are wired

  if (allRelaxed()) { if (!relaxedActive) { relaxedActive = true; relaxedStart = now; } }
  else relaxedActive = false;
  clearedNow = relaxedActive && (now - relaxedStart >= CLEAR_MS) && !killPressed();

  // ---- Hold REST while the sensors settle after power-up ----
  if (!settled) { fsmCur = S_REST; candCount = 0; return; }

  // ---- Walk the table ----
  uint8_t before = fsmCur;
  for (int i = 0; i < NUM_ROWS; i++) {
    if (TABLE[i].from != S_ANY && TABLE[i].from != fsmCur) continue;
    if (condTrue(TABLE[i].cond)) { fsmCur = TABLE[i].to; break; }    // first match wins
  }
#if LOG_CSV
  if (fsmCur != before) {
    Serial.print(F("EVENT ms:")); Serial.print(now);
    Serial.print(F(" state:"));   Serial.println(fsmCur);
  }
#endif
}

uint8_t fsmState()  { return fsmCur; }
bool    fsmAgreed() { return agreedNow; }