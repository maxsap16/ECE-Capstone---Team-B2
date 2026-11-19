"""record_session.py -- prompts gestures, records the Arduino's CSV, adds the label.

    python record_session.py --port COM3 --subject warden --reps 20

Needs the glove_main sketch running (it prints one CSV line every 50 ms).
Output: session_<subject>_<time>.csv  (subject column + the Arduino's columns, label filled in)
"""
import argparse, csv, random, time, datetime
import serial

GESTURES = ["REST", "OPEN", "FIST", "PINCH", "POINT"]     # label id = list index
HOLD_S, BREAK_S = 2.0, 2.0          # seconds recording each gesture / each relaxed gap
DROP_HOLD_S = 0.3                   # skip the start of a hold (reaction time)
DROP_REST_S = 0.7                   # skip the start of a rest gap (signal takes ~1 s to decay)
COUNTDOWN_S = 2
N_COLS = 20                         # fields in one Arduino row (the last one is the empty label)
HEADER = ("subject,ms,flexor,extensor,thumb,index,rule_guess,nn_guess,agreed,fsm_state,"
          "flex0,flex1,flex2,flex3,flex4,fsr0,fsr1,fsr2,fsr3,fsr4,label").split(",")

def record(ser, writer, subject, seconds, drop_s, label):
    """Record for `seconds`, skipping the first drop_s; write each good row with the label."""
    ser.reset_input_buffer()
    start = time.time()
    kept = 0
    while time.time() - start < seconds:
        line = ser.readline().decode(errors="ignore").strip()
        if not line or line.startswith("EVENT") or line.startswith("ms"):
            continue
        f = line.split(",")
        if len(f) != N_COLS or not f[0].isdigit():     # partial or garbled line
            continue
        if time.time() - start < drop_s:
            continue
        f[-1] = str(label)
        writer.writerow([subject] + f)
        kept += 1
    return kept

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", required=True)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--subject", required=True)
    ap.add_argument("--reps", type=int, default=20)
    a = ap.parse_args()

    ser = serial.Serial(a.port, a.baud, timeout=0.1)
    time.sleep(2)                                      # opening the port resets the Arduino
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = f"session_{a.subject}_{stamp}.csv"

    with open(out, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(HEADER)
        try:
            for rep in range(1, a.reps + 1):
                order = [1, 2, 3, 4]                   # OPEN, FIST, PINCH, POINT
                random.shuffle(order)
                for gid in order:
                    print(f"\nRep