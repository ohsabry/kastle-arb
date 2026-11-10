#!/bin/sh
# Kastle ARP in-circuit programming helper. Run ./prog.sh with no arguments for usage.
# Fuses are read but never written, and nothing in this script can write them.
set -eu
cd "$(dirname "$0")"

FQBN=attiny:avr:ATtinyX5:cpu=attiny85,clock=internal8
CORE_URL=https://raw.githubusercontent.com/damellis/attiny/ide-1.6.x-boards-manager/package_damellis_attiny_index.json
AVRDUDE_DIR=${AVRDUDE_DIR:-$(ls -d "$HOME"/Library/Arduino15/packages/arduino/tools/avrdude/* | tail -1)}
PROGRAMMER=${PROGRAMMER:-stk500v2}
BACKUPS=backup
VCO_MARK=$BACKUPS/VCO          # holds the label of the port that was identified as the VCO
TMP=build/tmp

# Known firmware to identify chips against. Pinned so results can't shift.
REF=build/reference
BASTL_URL=${BASTL_URL:-https://raw.githubusercontent.com/bastl-instruments/production/a47e6374487daa97673a2f6a794b160f3f766938/attiny}
CLONE_URL=${CLONE_URL:-https://raw.githubusercontent.com/wonkystuff/kastle_clones/329c1246afdd5242a2ac2d515de72f5d57613503/kastleArp/kastleArp.hex}

die() { echo "STOPPED: $*" >&2; exit 1; }
fw() { python3 -I tools/fw.py "$@"; }

dude() {
  [ -n "${PORT:-}" ] || die "set PORT first, e.g. PORT=/dev/cu.usbmodem12345 ./prog.sh $CMD"
  "$AVRDUDE_DIR/bin/avrdude" -C "$AVRDUDE_DIR/etc/avrdude.conf" -q -c "$PROGRAMMER" -P "$PORT" -p t85 "$@"
}

need_label() {
  case "${1:-}" in
    ''|*[!a-z0-9-]*) die "give the port a lowercase label, e.g. ./prog.sh $CMD left" ;;
  esac
}

read_chip() { # read_chip <dir>: flash, EEPROM, fuses and lock byte into <dir>
  mkdir -p "$1"
  dude -U flash:r:"$1/flash.hex":i -U flash:r:"$1/flash.bin":r -U eeprom:r:"$1/eeprom.hex":i \
       -U lfuse:r:"$1/lfuse.txt":h -U hfuse:r:"$1/hfuse.txt":h -U efuse:r:"$1/efuse.txt":h \
       -U lock:r:"$1/lock.txt":h
}

fetch_refs() {
  mkdir -p "$REF"
  while read -r name url; do
    [ -s "$REF/$name" ] || curl -sSfL -o "$REF/$name" "$url" || { rm -f "$REF/$name"; return 1; }
  done <<REFS
VCO-Bastl-final-RC7.hex $BASTL_URL/kastleArp.hex
VCO-Bastl-RC1.hex $BASTL_URL/kastleArpArchive/kastleArpRC.hex
VCO-Bastl-RC2.hex $BASTL_URL/kastleArpArchive/kastleArpRC2.hex
VCO-Bastl-RC3.hex $BASTL_URL/kastleArpArchive/kastleArp_RC3.hex
VCO-Bastl-RC4.hex $BASTL_URL/kastleArpArchive/kastleArp_RC4.hex
VCO-Bastl-RC5.hex $BASTL_URL/kastleArpArchive/kastleArpRC5.hex
VCO-Bastl-RC6.hex $BASTL_URL/kastleArpArchive/kastleArpRC6.hex
VCO-wonkystuff-clone-5-chord.hex $CLONE_URL
LFO-Bastl-Drum.hex $BASTL_URL/kastleDRUM_CLK_LFO.ino.hex
LFO-Bastl-v1.5.hex $BASTL_URL/KASTLE_LFO.hex
REFS
}

# Report only. Never changes the backup, and a failure here doesn't undo it.
identify() {
  d=$BACKUPS/$1
  [ -f "$d/flash.bin" ] || die "no backup called $1"
  if fw isvco "$d/flash.bin"; then
    if [ -f "$VCO_MARK" ] && [ "$(cat "$VCO_MARK")" != "$1" ]; then
      die "$1 and $(cat "$VCO_MARK") both look like the VCO. Don't flash anything, something is wrong."
    fi
    echo "$1" > "$VCO_MARK"
    echo "Port $1 is the VCO chip."
  else
    echo "Port $1 is NOT the VCO chip. Never write to this port."
  fi
  if fetch_refs; then
    fw match "$d/flash.bin" "$REF"/*.hex || echo "Couldn't compare firmware. The backup is fine."
  else
    echo "Couldn't download the reference firmware. The backup is fine, run ./prog.sh identify $1 later."
  fi
  if [ "$(cat "$d/lfuse.txt")" = 0xe2 ] && [ "$(cat "$d/hfuse.txt")" = 0xdf ] && [ "$(cat "$d/efuse.txt")" = 0xff ]; then
    echo "Fuses match Bastl's production values."
  else
    echo "Note: fuses differ from Bastl's production values (L=0xe2 H=0xdf E=0xff). Leave them alone."
  fi
}

# Only the VCO chip may be written. Reads the connected chip to confirm that.
vco_guard() {
  [ -f "$VCO_MARK" ] || [ "${I_CHECKED_PORT:-}" = vco ] || die "no VCO backup yet, back up both ports first"
  mkdir -p "$TMP"; rm -f "$TMP/now.bin"
  dude -U flash:r:"$TMP/now.bin":r
  vco=$(cat "$VCO_MARK" 2>/dev/null || true)
  for d in "$BACKUPS"/*/; do
    [ -d "$d" ] || continue
    label=$(basename "$d")
    [ "$label" != "$vco" ] || continue
    if cmp -s "$TMP/now.bin" "$d/flash.bin"; then
      die "this is port $label, not the VCO. Move the programmer to port $vco."
    fi
  done
  [ "${I_CHECKED_PORT:-}" != vco ] || return 0
  fw isvco "$TMP/now.bin" || die "this chip has no ARP tuning table, so it may be the LFO. If a flash to the VCO port failed partway, it may just be blank: confirm you're on the VCO port and rerun with I_CHECKED_PORT=vco"
}

write_vco() { # write_vco <hex>: flash, then put back the saved EEPROM the erase wipes
  vco_guard
  vco=$(cat "$VCO_MARK" 2>/dev/null || true)
  if [ -n "$vco" ]; then
    dude -U flash:w:"$1":i -U eeprom:w:"$BACKUPS/$vco/eeprom.hex":i \
      || die "write failed, usually a loose header. Reseat it and run the same command again. Fuses weren't touched."
  else
    dude -U flash:w:"$1":i \
      || die "write failed, usually a loose header. Reseat it and run the same command again. Fuses weren't touched."
  fi
  echo "Written and verified."
}

CMD=${1:-}
case "$CMD" in
build)
  python3 -I tools/diag/make_diag.py >/dev/null || die "couldn't generate the measuring build"
  # Arduino needs a sketch inside a folder of the same name, so compile from a copy.
  for v in stock maqam diag; do
    case $v in stock) src=stock/kastleArp.ino ;; maqam) src=kastl-arb.ino ;; diag) src=tools/diag/kastleArp.ino ;; esac
    mkdir -p "build/src/$v/kastleArp"
    cp "$src" "build/src/$v/kastleArp/kastleArp.ino"
    rm -f "build/$v/kastleArp.ino.hex"
    arduino-cli compile -b "$FQBN" --additional-urls "$CORE_URL" --output-dir "build/$v" "build/src/$v/kastleArp" 2>&1 \
      | grep -E 'error|Sketch uses|Global variables' || true
    [ -f "build/$v/kastleArp.ino.hex" ] || die "$v did not build"
  done
  ;;
check) # read only: target voltage and chip ID
  out=$(dude -v 2>&1) || true
  printf '%s\n' "$out" | grep -E 'Vtarget|Device signature|rror' || true
  printf '%s\n' "$out" | grep -q '1E 93 0B' && { echo "Connected to an ATtiny85."; exit 0; }
  volts=$(printf '%s\n' "$out" | awk '/Vtarget/ {print $3}')
  case "$volts" in
    0.*) die "no power from the Kastle. Is the ribbon on the programmer, the Kastle switched on, and the red and black wires in?" ;;
    *) die "power is there but the chip didn't answer. Check DECAY is at 12 o'clock, no patch cables are in, and the wires are seated." ;;
  esac
  ;;
backup) # read only: never writes to the chip
  need_label "${2:-}"
  L=$2
  [ ! -e "$BACKUPS/$L" ] || die "$BACKUPS/$L already exists, move it aside first. It may be your only copy."
  rm -rf "$TMP"
  read_chip "$TMP/read1"
  read_chip "$TMP/read2"
  for f in flash.hex eeprom.hex lfuse.txt hfuse.txt efuse.txt lock.txt; do
    cmp -s "$TMP/read1/$f" "$TMP/read2/$f" || die "$f differed between two reads, reseat the header and retry"
  done
  [ -s "$TMP/read1/flash.bin" ] || die "flash read back empty, check the header and that the Kastle is on"
  lock=$(( $(cat "$TMP/read1/lock.txt") & 3 ))
  [ "$lock" -eq 3 ] || die "lock bits are set, so this read is not the real firmware. Nothing was saved."
  mkdir -p "$BACKUPS" && mv "$TMP/read1" "$BACKUPS/$L"
  (cd "$BACKUPS/$L" && shasum -a 256 ./* > SHA256SUMS)
  d=$BACKUPS/$L
  echo "Backup saved to $d. Fuses: L=$(cat "$d/lfuse.txt") H=$(cat "$d/hfuse.txt") E=$(cat "$d/efuse.txt")"
  identify "$L"
  ;;
identify)
  need_label "${2:-}"
  identify "$2"
  ;;
flash-stock|flash-maqam|flash-diag)
  v=${CMD#flash-}
  [ -f "build/$v/kastleArp.ino.hex" ] || die "run ./prog.sh build first"
  write_vco "build/$v/kastleArp.ino.hex"
  ;;
diag-read) # read only: shows what the measuring build logged
  mkdir -p build/measure; rm -f build/measure/eeprom.hex
  dude -U eeprom:r:build/measure/eeprom.hex:i
  fw diag build/measure/eeprom.hex
  ;;
restore)
  [ -f "$VCO_MARK" ] || die "no VCO backup to restore"
  write_vco "$BACKUPS/$(cat "$VCO_MARK")/flash.hex"
  ;;
*)
  cat <<USAGE
./prog.sh build                     compile stock and maqam
PORT=... ./prog.sh check            confirm the programmer can see the chip
PORT=... ./prog.sh backup <label>   read one port (read only), e.g. backup left
./prog.sh identify <label>          re-run the firmware check on a backup
PORT=... ./prog.sh flash-stock      flash stock to the VCO chip
PORT=... ./prog.sh flash-maqam      flash maqam to the VCO chip
PORT=... ./prog.sh flash-diag       flash the measuring build to the VCO chip
PORT=... ./prog.sh diag-read        show what the measuring build logged (read only)
PORT=... ./prog.sh restore          flash the VCO backup back
USAGE
  ;;
esac
