#!/usr/bin/env python3
"""Print Backrest backup status as key=value lines for the bar widget.

Reads Backrest's oplog read-only, so it needs no API login.
"""
import os
import sqlite3
import subprocess
import time

DB = os.path.expanduser("~/.local/share/backrest/oplog.sqlite")
OP_BACKUP = 100  # Operation.operation_backup field number
STATUS = {0: "unknown", 1: "pending", 2: "running", 3: "success", 4: "error",
          5: "cancelled", 6: "cancelled", 7: "warning"}


def varint(b, i):
    r = s = 0
    while True:
        c = b[i]
        i += 1
        r |= (c & 0x7F) << s
        s += 7
        if c < 0x80:
            return r, i


def fields(b):
    i, out = 0, {}
    while i < len(b):
        key, i = varint(b, i)
        num, wire = key >> 3, key & 7
        if wire == 0:
            v, i = varint(b, i)
        elif wire == 2:
            n, i = varint(b, i)
            v, i = b[i:i + n], i + n
        elif wire == 1:
            v, i = b[i:i + 8], i + 8
        elif wire == 5:
            v, i = b[i:i + 4], i + 4
        else:
            break
        out.setdefault(num, v)
    return out


service = subprocess.run(["systemctl", "--user", "is-active", "backrest.service"],
                         capture_output=True, text=True).stdout.strip()
print(f"service={service}")

try:
    db = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=2)
    rows = db.execute("SELECT status, start_time_ms, operation FROM operations "
                      "ORDER BY start_time_ms DESC LIMIT 200").fetchall()
except sqlite3.Error as e:
    print(f"error=oplog: {e}")
    raise SystemExit

now_ms = int(time.time() * 1000)
last = last_ok = nxt = None
running = False
for status, start, blob in rows:
    f = fields(blob)
    if OP_BACKUP not in f:
        continue
    if status == 1 and start > now_ms:
        nxt = start if nxt is None else min(nxt, start)
        continue
    if status == 2:
        running = True
        continue
    if last is None and status not in (1, 2):
        last = (status, start, f.get(6, start), f.get(7, b"").decode(errors="replace"))
    if last_ok is None and status in (3, 7):
        last_ok = f.get(6, start)

print(f"running={int(running)}")
if last:
    print(f"last_status={STATUS.get(last[0], 'unknown')}")
    print(f"last_end={last[2] // 1000}")
    if last[3]:
        print("last_message=" + last[3].splitlines()[0][:200])
if last_ok:
    print(f"last_ok={last_ok // 1000}")
if nxt:
    print(f"next={nxt // 1000}")
