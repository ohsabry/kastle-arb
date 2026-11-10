# kastl-arb

Maqam firmware for the Bastl Kastle ARP.

Out of the box, the Kastle ARP lives in major triads. Whatever you do with the NOTE knob or the
LFO, you land on a note of C, F or G major. This firmware swaps those triads for maqam scales,
quarter tones and all, so the same knob and the same LFO patches now walk through Bayati, Rast
and Saba.

Everything else stays the way Bastl made it: the LFO, the pattern generator, decay skipping,
TIMBRE and boot mode. Only the ARP's VCO chip gets new firmware. The LFO chip is never touched,
and you can put the factory firmware back whenever you like.

## What it plays

The root is C unless you change it in boot mode. The CHORD patch point picks the scale:

| CHORD | Maqam | Notes | Drone |
| --- | --- | --- | --- |
| unplugged | Bayati | C · D½♭ · E♭ · F · G · A♭ · B♭ | C |
| `+` | Bayati with Rast on top | C · D½♭ · E♭ · F · G · A½♭ · B♭ | F |
| `−` | Saba, roughly | C · D½♭ · E♭ · F♭ · G · A♭ · B♭ | E♭ |

½♭ means half-flat: a quarter tone down. D half-flat sits halfway between D♭ and D, and A
half-flat halfway between A♭ and A. That in-between note is the sound of Bayati.

A bit more about each:

- **Bayati** is home. The lower half of the scale, C D½♭ E♭ F, carries the character, and the
  drone holds C.
- **`+`** keeps Bayati's lower half but swaps the upper half for Rast, built on F, which raises
  A♭ to A half-flat. The drone moves to F, the scale's pivot note, the way an oud player shifts
  the bass when the melody moves up.
- **`−`** is Saba, the most mournful of the three. The fourth note drops to F♭. Real Saba also
  flattens the fifth and changes from octave to octave. This version keeps the same seven notes
  in every octave so it stays playable across the whole knob, which makes it an approximation.
  The drone sits on E♭, Saba's pivot.

### Range

There are 29 notes, four full octaves from C at 65 Hz up to C at 1,043 Hz. The top note is the
home note, so runs up the scale finish where they should.

The notes start at about 9 o'clock on the NOTE knob. From fully left to 9 o'clock nothing
changes. That's the Kastle's circuit, not the firmware: the knob's voltage doesn't reach the chip
until then, and the stock firmware has the same dead zone. From 9 o'clock to fully right, the
notes are spaced evenly. If NOTE MOD pushes past the top, it holds the top C.

### Drone

Patch BASS into ARP to hear it. It sits at the bottom of the melody's range, 65 to 87 Hz, an
octave higher than stock, so you can actually hear it on small speakers.

### Tuning

Every note lands within about 3 cents of its target in 24-tone equal temperament, and the drone
within about 1.5 cents of the melody. That's well inside what an ear can pick out. Like stock,
the whole instrument sits a few cents flat until you set fine tune in boot mode.

### Boot mode

Boot mode is unchanged from stock. Unplug everything, patch CHORD to `+`, turn NOTE, TIMBRE and
DECAY fully right, then power up. TIMBRE sets the root, with C fully left, and DECAY sets fine
tune, with A=440 around the middle. NOTE previews the scale. Unplug CHORD to save and leave.

## Putting it on your Kastle

You'll need an AVR ISP programmer, six jumper wires, a few header pins and about half an hour.
[HOWTO.md](HOWTO.md) walks through all of it, including backing up your factory firmware first
and putting it back afterwards.

## How it differs from Bastl's firmware

- Three seven-note maqam scales replace the three triads, with notes stored in quarter tones.
- The NOTE knob covers four octaves instead of about seven, so each note gets a decent slice of
  the turn. The notes are fitted to the knob's measured range instead of the full 0–255.
- The melody starts an octave higher, at C2, and the drone moves up an octave to match.
- The low notes read their pitch from a more precise part of Bastl's tuning table, which tightens
  the tuning at the bottom.
- The drone follows CHORD straight away, even with DECAY turned left, where stock waited for the
  next note.
- Two edge cases in the stock code are closed off: knob readings above 250, and high root
  settings running past the end of the tuning table.

## What's in here

- `kastl-arb.ino`: the firmware.
- `stock/`: Bastl's original, unmodified, plus a note of exactly which version it is.
- `prog.sh`: builds the firmware, backs up the chips and flashes them, with safety checks.
- `tools/`: firmware identification, and a measuring build that logs what the knob and notes
  are really doing.
- `tests/`: runs the firmware on your computer and checks every note, before it goes near the
  chip.
- `HOWTO.md`: the step-by-step guide.

## Licence

Based on [Bastl Instruments' Kastle code](https://github.com/bastl-instruments/kastle), which
Bastl releases as CC-BY-SA. This version is released under the same licence. See
[LICENSE](LICENSE).
