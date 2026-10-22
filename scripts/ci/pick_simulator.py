#!/usr/bin/env python3
"""Prints the UDID of an available iPhone simulator on the newest iOS runtime.

Usage: xcrun simctl list devices available -j | python3 pick_simulator.py [preferred name...]
"""
import json
import re
import sys

preferred = sys.argv[1:] or ["iPhone 16", "iPhone 16 Pro", "iPhone 15"]
devices = json.load(sys.stdin)["devices"]
candidates = []
for runtime, entries in devices.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in entries:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            rank = preferred.index(device["name"]) if device["name"] in preferred else len(preferred)
            candidates.append((version, -rank, device["name"], device["udid"]))
if not candidates:
    sys.exit("No available iPhone simulator found")
candidates.sort()
version, _, name, udid = candidates[-1]
print(f"Selected {name} (iOS {version[0]}.{version[1]})", file=sys.stderr)
print(udid)
