"""train_nn.py -- trains the small network from recorded sessions and writes nn_weights.h.

    python train_nn.py --csv "session_*.csv"
    python train_nn.py --csv "session_*.csv" --out ../glove_main/nn_weights.h

Reads the files record_session.py writes. Prints per-gesture accuracy for:
  rule decoder, network, both-agree, and the FSM state (what the glove actually did).
With 2+ people it holds each person out in turn (the number that matters for a NEW user).
With one person it holds out the last 20% of the recording and warns you.
"""
import argparse, csv, glob, math
import numpy as np
from sklearn.neural_network import MLPClassifier

CH = ["flexor", "extensor", "thumb", "index"]
NAMES = ["REST", "OPEN", "FIST", "PINCH", "POINT"]
HIDDEN = 8
N_OUT = len(NAMES)

def load(patterns):
    subj, X, y, rule, state = [], [], [], [], []
    for pat in patterns:
        for path in sorted(glob.glob(pat)):
            with open(path, newline="") as fh:
                for r in csv.DictReader(fh):
                    try:
                        x = [int(r[c]) for c in CH]
                        lab = int(r["label"]); ru = int(r["rule_guess"]); st = int(r["fsm_state"])
                    except (ValueError, KeyError):
                        continue                       # blank label or short row
                    subj.append(r["subject"]); X.append(x); y.append(lab); rule.append(ru); state.append(st)
    X = np.clip(np.array(X, float) / 4.0, 0, 255)      # 10-bit counts -> 0..255 (same scaling on the Arduino)
    return np.array(subj), X, np.array(y), np.array(rule), np.array(state)

def fit(X, y):
    return MLPClassifier((HIDDEN,), max_iter=1000, random_state=0).fit(X / 255.0, y)

def per_gesture(y, pred):
    out = []
    for c in range(N_OUT):
        m = y == c
        out.append(float((pred[m] == c).mean()) if m.any() else float("nan"))
    return out

def report(title, y, nn, rule, state):
    agree = nn == rule
    both = np.where(agree, nn, -1)                      # -1 = the two disagreed, no gesture committed
    print(f"\n{title}   ({len(y)} rows)")
    print(f"  {'gesture':8s} {'rules':>7s} {'network':>8s} {'both agree':>11s} {'FSM state':>10s}")
    r, n, b, s = per_gesture(y, rule), per_gesture(y, nn), per_gesture(y, both), per_gesture(y, state)
    for c in range(N_OUT):
        print(f"  {NAMES[c]:8s} {r[c]:7.1%} {n[c]:8.1%} {b[c]:11.1%} {s[c]:10.1%}")
    print(f"  {'overall':8s} {(rule==y).mean():7.1%} {(nn==y).mean():8.1%} {(both==y).mean():11.1%} {(state==y).mean():10.1%}")
    print(f"  the two decoders agreed on {agree.mean():.1%} of rows")

def quantize(clf, Xtrain):
    W1, W2 = clf.coefs_; b1, b2 = clf.intercepts_
    s1 = 127 / np.abs(W1).max(); s2 = 127 / np.abs(W2).max()
    W1q = np.round(W1 * s1).astype(int); b1q = np.round(b1 * s1 * 255).astype(int)
    acc1 = np.maximum(Xtrain.astype(int) @ W1q + b1q, 0)       # pick the shift so hidden values fit 0..255
    p99 = max(float(np.percentile(acc1, 99)), 1.0)
    sh1 = max(0, math.ceil(math.log2(p99 / 255.0)))
    k = s1 * 255 / 2 ** sh1
    W2q = np.round(W2 * s2).astype(int); b2q = np.round(b2 * s2 * k).astype(int)
    return W1q, b1q, W2q, b2q, sh1

def int_predict(X, W1q, b1q, W2q, b2q, sh1):
    h = np.minimum(np.maximum(X.astype(int) @ W1q + b1q, 0) >> sh1, 255)
    return np.argmax(h @ W2q + b2q, axis=1)

def arr(vals): return ", ".join(str(int(v)) for v in vals)

def write_header(path,