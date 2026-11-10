#!/usr/bin/env python3
"""Firmware helpers for prog.sh. Reads files only, never touches the chip."""
import os
import struct
import sys

# Start of dcoTable. In every Kastle ARP version and in our maqam build, and in no LFO firmware.
TUNING_TABLE = struct.pack('<8H', 69, 73, 77, 81, 86, 91, 96, 102)


def read_hex(path):
    mem = bytearray()
    base = 0
    for line in open(path):
        line = line.strip()
        if not line.startswith(':'):
            continue
        n, addr, kind = int(line[1:3], 16), int(line[3:7], 16), int(line[7:9], 16)
        data = bytes.fromhex(line[9:9 + n * 2])
        if kind == 0:
            start = base + addr
            mem.extend(b'\xff' * max(0, start + n - len(mem)))
            mem[start:start + n] = data
        elif kind == 2:
            base = int.from_bytes(data, 'big') << 4
        elif kind == 4:
            base = int.from_bytes(data, 'big') << 16
    return bytes(mem).rstrip(b'\xff')


def read_bin(path):
    return open(path, 'rb').read().rstrip(b'\xff')


def diag(path):
    """Summarises what the measuring build (tools/diag) logged into EEPROM."""
    mem = bytearray(b'\xff' * 512)
    raw = read_hex(path)
    mem[:len(raw)] = raw
    if mem[63] != 0xA5:
        print('No measurement here: the measuring build has not run since this EEPROM was written.')
        return
    readings = [v for v in range(256) if mem[64 + (v >> 3)] & (1 << (v & 7))]
    notes = [w for w in range(32) if mem[96 + (w >> 3)] & (1 << (w & 7))]
    if not readings:
        print('Logging started, but no NOTE readings yet.')
        return
    gaps = [(a, b) for a, b in zip(readings, readings[1:]) if b - a > 1]
    print('NOTE readings: %d to %d, %d different values' % (readings[0], readings[-1], len(readings)))
    print('Jumps in the readings: %s' % (', '.join('%d to %d' % g for g in gaps) if gaps else 'none'))
    if mem[96:100] == b'\xff\xff\xff\xff':
        print('Notes that sounded: not recorded (this log is from the older, knob-only measuring build)')
    elif notes:
        top = max(notes)
        missing = [w for w in range(top + 1) if w not in notes]
        print('Notes that sounded: %d, from note 0 up to note %d' % (len(notes), top))
        print('Notes skipped below the top one: %s' % (', '.join(map(str, missing)) if missing else 'none'))


def main():
    cmd, chip_path = sys.argv[1], sys.argv[2]
    if cmd == 'diag':
        diag(chip_path)
        return
    chip = read_bin(chip_path)
    if cmd == 'isvco':
        sys.exit(0 if TUNING_TABLE in chip else 1)
    if cmd == 'match':
        print('Firmware size: %d bytes' % len(chip))
        hits = [os.path.basename(p)[:-4] for p in sys.argv[3:] if read_hex(p) == chip]
        print('Matches: ' + ', '.join(hits) if hits else 'No match in the known firmware.')


main()
