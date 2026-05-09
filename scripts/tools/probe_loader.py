#!/usr/bin/env python3
"""
Probe the loader running inside VICE via the text remote monitor.
Usage: python3 scripts/tools/probe_loader.py [port]
"""
import socket, sys, time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 6520

def rd(s):
    s.settimeout(0.7)
    buf = b""
    while True:
        try:
            c = s.recv(8192)
        except Exception:
            break
        if not c:
            break
        buf += c
    return buf.decode("ascii", errors="replace")

s = socket.socket()
s.settimeout(3)
s.connect(("127.0.0.1", PORT))
print(rd(s))

CMDS = [
    "r",
    "m 0001 0001",
    "m d011 d012",
    "m d020 d022",
    "m d018 d018",
    "m d01a d01a",
    "m 0314 0315",
    "m 080d 0825",
    "m 0400 0427",
    "m 05e0 0607",
    "m b43e b450",
    "x",
]
for cmd in CMDS:
    s.sendall((cmd + "\n").encode())
    time.sleep(0.4)
    print(f"--- {cmd} ---")
    print(rd(s))
s.close()
