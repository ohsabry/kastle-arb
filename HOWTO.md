# Putting the maqam firmware on a Kastle ARP

This is how I did it on a Kastle SMT v1.7.1 with a Mac. It's written for someone who hasn't
programmed a chip before. The short version: back up both chips, flash Bastl's own firmware once
as a rehearsal, then flash the maqam version. If anything goes wrong, you can always put the
factory firmware back.

## What you need

- **An AVR ISP programmer.** I used a Pololu USB AVR Programmer v2.1. Its ribbon cable is
  handy, but it can't plug straight into the Kastle, so you'll also need the next two items.
- **Six male-to-female jumper wires**, ideally in six colours.
- **A 2×3 block of 0.1″ header pins**, snapped off a breakaway strip.
- **A 2 mm hex key** to open the case.
- **A Mac with Homebrew.** The scripts assume macOS.
- **Python 3.9 or newer.** The one that comes with Apple's command-line tools is fine. The helper
  scripts use only Python's standard library, and they've been tested on 3.9.6 and 3.14.7.

## Setting up the software

Install the Arduino command-line tools and the ATtiny board definitions:

    brew install arduino-cli
    URL=https://raw.githubusercontent.com/damellis/attiny/ide-1.6.x-boards-manager/package_damellis_attiny_index.json
    arduino-cli core update-index --additional-urls $URL
    arduino-cli core install arduino:avr attiny:avr --additional-urls $URL

That's the whole toolchain. This setup builds Bastl's original firmware byte for byte identical
to their factory release, which is a good sign it'll build this one correctly too.

Check that the firmware builds and passes its tests:

    ./prog.sh build
    tests/run.sh

The tests should end with "all checks passed".

## Finding the programmer

Plug the programmer into your Mac. It shows up as two ports:

    ls /dev/cu.usbmodem*

Only one is for programming, usually the first. To find out which, try one:

    PORT=/dev/cu.usbmodemXXXXXXX ./prog.sh check

The programming port answers and reports a voltage, while the other one just times out. Neither
can do any harm. Once you know it, keep it for the rest of the session:

    export PORT=/dev/cu.usbmodemXXXXXXX

## Opening the Kastle

Take out the screw on the top panel with the 2 mm key, undo the nut around the power switch, and
lift the panel off. Nothing else needs undoing, and in particular leave the battery holder's
screw alone.

You'll see two groups of six holes, one for each chip. Each group is labelled:

    +5V   MISO
    MOSI  SCK
    GND   RES

On my Kastle the right group was the VCO, the chip that gets reprogrammed, and the left was the
LFO. Don't assume yours matches: the backup step tells you which is which.

## Wiring it up

The Kastle's holes are laid out as a mirror image of the standard programming connector, so the
ribbon cable can't go straight on. No way of turning it lines everything up. Instead, the ribbon
stays on the programmer, and six jumpers run from its loose plug to the Kastle, matched by name.

1. Press the 2×3 header block into the holes of one port, short side down.
2. Find pin 1 on the ribbon's loose plug: it's at the red-wire end, on the side a small moulded
   triangle points to. Looking into the plug's holes with the red wire at the top and the
   triangle on the right, the holes are:

        +5V    MISO     ← red-wire end
        MOSI   SCK
        GND    RES

3. Run a jumper from each plug hole to the header pin with the same name. Here are the colours I
   used. Any colours work, as long as you can tell them apart:

   | Line | Colour |
   | --- | --- |
   | +5V | red |
   | MOSI | yellow |
   | GND | black |
   | MISO | orange |
   | SCK | green |
   | RES | white |

   Handily, the plug and the Kastle port end up with the same layout, so the colours sit in the
   same places at both ends.

If you're unsure, connect only red and black first and run `./prog.sh check`. You should see
about 5 V on USB, or about 4.5 V on batteries. A power wire in the wrong hole just reads 0 V and
does no harm.

## Before every programming step

- **Pull out every patch cable.** CHORD shares a pin with the chip's reset line, so a cable there
  stops the programmer getting in.
- **Set DECAY to about 12 o'clock.** The DECAY knob shares a pin with the programmer's clock line.
  Turned fully right, it overpowers the programmer and nothing works. This one cost me half an
  hour.
- **Power the Kastle from its own USB or batteries.** USB is safer for writing. Leave the
  programmer's power output off, which is how it ships.

Then check the connection:

    ./prog.sh check

You want to see `1E 93 0B (ATtiny85)` and "Connected to an ATtiny85".

## Step 1: back up both chips

Label each port by where it sits. With the header in one port:

    ./prog.sh backup left

Move the header to the other port, keeping it turned the same way, and run:

    ./prog.sh backup right

These only read. Each one reads the chip twice and compares, then tells you whether that port is
the VCO and which firmware it's running. For a stock ARP you should see one port match
`LFO-Bastl-Drum` and the other `VCO-Bastl-final-RC7`.

If the VCO shows anything other than `VCO-Bastl-final-RC7`, stop and look into it before
flashing. Your unit is running a version this firmware wasn't built against.

Copy the `backup/` folder somewhere safe. Git ignores it on purpose.

## Step 2: rehearse with Bastl's firmware

With the header on the VCO port:

    ./prog.sh flash-stock

This writes Bastl's original firmware, which for a stock unit is exactly what's already there.
If something goes wrong, you'll find out while the fix is simply running the command again.

## Step 3: flash the maqam firmware

    ./prog.sh flash-maqam

That's it. Pull out the ribbon, patch it up and play. The [README](README.md) describes what you
should hear.

## Going back to factory

    ./prog.sh restore

This writes your own backup of the VCO back, firmware and settings.

## What the script does for you

Every write goes through the same checks:

- **Fuses:** it never writes them. They're the chip's settings for clock and reset, and getting
  them wrong is the one way to really lock yourself out. `prog.sh` has no command that writes
  them.
- **Port check:** before writing, it reads the connected chip and refuses unless it's the VCO.
  The LFO firmware has no tuning table, so the two are easy to tell apart.
- **Verifying:** avrdude reads every write back to confirm it.
- **Settings:** flashing erases the chip's EEPROM, where boot mode keeps your root and fine tune,
  so the script writes your backed-up settings straight back.

## When things go wrong

| You see | It's probably | Do this |
| --- | --- | --- |
| About 0 V | The ribbon isn't on the programmer, the Kastle is off, or a power wire is out | Check those three |
| Normal voltage, but `initialization failed` | DECAY turned fully right, a patch cable in CHORD, or a loose signal wire | DECAY to 12 o'clock, cables out, reseat the header |
| "differed between two reads" | The press-fit header lost contact for a moment | Reseat it and run again |
| A write fails partway | Same, a loose contact | Run the same command again. The chip may sit blank until it succeeds, but that's not damage. |
| The guard refuses a half-written VCO | The chip no longer looks like a VCO | Make sure you're on the VCO port, then run it again with `I_CHECKED_PORT=vco` in front |

## Measuring your own Kastle

The note layout was fitted to my Kastle's knob, which reads up to about 222 on batteries and
225 on USB. Another unit could differ a little. To check yours:

    ./prog.sh flash-diag

This build plays exactly like the maqam firmware, and it also logs every knob reading and every
note that sounds. Leave the ribbon in and DECAY at 12 o'clock. Sweep NOTE slowly from fully left
to fully right and back, twice, without switching off, since a power cycle clears the log. Then:

    ./prog.sh diag-read

It tells you the knob's range, any jumps, and whether every note sounded. When you're done, run
`./prog.sh flash-maqam` to go back to the normal firmware.

## Changing the scales yourself

Everything musical is near the top of `kastl-arb.ino`:

- **`_scales`** holds the three scales, seven notes each, counted in quarter tones above the root.
  2 is a semitone and 1 is a quarter tone. Bayati is `0, 3, 6, 10, 14, 16, 20`. The rows are, in
  order: a spare row nothing uses, then `−`, unplugged and `+`.
- **`rootToPitch`** sets the drone note in semitones above the root. Only three of its eight
  entries matter: entry 2 is `−`, 4 is unplugged and 6 is `+`.
- **`pitchMap`, `TOP_WINDOW` and `START_QT`** set how many notes the knob covers, how they're
  spread, and where the bottom note sits.

After any change, run `tests/run.sh` first. It catches a surprising amount before anything
reaches the chip. Then run `./prog.sh build` and `./prog.sh flash-maqam`.
