# pip install pyserial
import serial, threading, sys

PORT = "COM3"        # change to your port
FILE = "test1.csv"   # output file

ser = serial.Serial(PORT, 115200, timeout=0.1)

def reader():
    with open(FILE, "w") as f:
        while True:
            line = ser.readline().decode(errors="ignore").strip()
            if not line:
                continue
            if line.startswith("EVENT"):
                print(line)                      # show state changes on screen only
            elif "," in line:
                f.write(line + "\n")
                f.flush()

threading.Thread(target=reader, daemon=True).start()
print("Logging to", FILE, "- type f / e / 0 / k then Enter to send keys. Ctrl+C to stop.")
try:
    for typed in sys.stdin:
        ser.write(typed.strip().encode())
except KeyboardInterrupt:
    pass