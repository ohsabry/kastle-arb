// Runs the real sketch logic on the Mac. Build and run with tests/run.sh.
#include <initializer_list>
#include <stdio.h>
#include <math.h>
#include "shim.h"
#include SKETCH

static int fails = 0;
#define CHECK(c, ...) do { if (!(c)) { fails++; printf("FAIL: " __VA_ARGS__); puts(""); } } while (0)

static const double FS = 15625.0;
static double hz(uint32_t f) { return f * FS / 65536.0; }
static double cents(double a, double b) { return 1200.0 * log2(a / b); }

static void step(uint8_t chordAdc, uint8_t knob, uint8_t decay = 255) {
  analogValues[0] = chordAdc; analogValues[WS_2] = decay; pitchAverage = knob;
  for (int i = 0; i < 3; i++) loop();
}
static void reset(uint8_t t, uint8_t fine) {
  transpose = t; fineTune = fine; window = 0; root = 0; lastRoot = 0; bootMode = false;
  decayVolume = 0; pitch = 0;
}

static const uint8_t ADC_MINUS = 100, ADC_OPEN = 155, ADC_PLUS = 200;
static const uint8_t SCALE[3][7] = {
  {0,3,6,8,14,16,20}, {0,3,6,10,14,16,20}, {0,3,6,10,14,17,20} };
static const uint8_t CHORD_ADC[3] = {ADC_MINUS, ADC_OPEN, ADC_PLUS};
static const char *NAME[3] = {"minus/Saba", "open/Bayati", "plus/Rast"};
static const int BASS[3] = {3, 0, 5};

int main() {
  startupRead = 48;
  setup();

  // 1. Every knob value, CHORD, transpose and fine tune: stays in the table (ASan
  //    catches any overrun) and the note is one the scale contains.
  for (int c = 0; c < 3; c++) for (int t = 0; t <= 13; t++) for (int f : {0, 120, 128, 255})
    for (int k = 0; k < 256; k++) {
      reset(t, f); step(CHORD_ADC[c], k);
      CHECK(frequency > 0 && frequency2 > 0, "zero frequency c=%d t=%d k=%d", c, t, k);
      uint8_t q = pitch % 24, in = 0;
      for (int i = 0; i < 7; i++) in |= SCALE[c][i] == q;
      CHECK(in, "note %d not in %s", q, NAME[c]);
    }

  // 2. Slow sweeps one ADC count at a time, up and down: every note in order, none skipped.
  for (int c = 0; c < 3; c++) {
    reset(0, 128); step(CHORD_ADC[c], 0);
    int g = 0;
    for (int k = 0; k < 256; k++) { step(CHORD_ADC[c], k);
      CHECK(window == g || window == g + 1, "%s up: k=%d window %d after %d", NAME[c], k, window, g);
      g = window; }
    CHECK(g == TOP_WINDOW, "%s up: top window %d", NAME[c], g);
    for (int k = 255; k >= 0; k--) { step(CHORD_ADC[c], k);
      CHECK(window == g || window == g - 1, "%s down: k=%d window %d after %d", NAME[c], k, window, g);
      g = window; }
    CHECK(g == 0, "%s down: bottom window %d", NAME[c], g);
  }

  // 2b. The real knob tops out at 222 (measured). A slow sweep that stops there, or at
  //     210, must still reach the top note, and every note on the way.
  for (int top : {210, 222}) for (int c = 0; c < 3; c++) {
    reset(0, 128); step(CHORD_ADC[c], 0); int g = 0, ok = 1;
    for (int k = 0; k <= top; k++) { step(CHORD_ADC[c], k); if (window != g && window != g + 1) ok = 0; g = window; }
    CHECK(ok && g == TOP_WINDOW, "%s sweep to %d: ended on window %d, steps ok %d", NAME[c], top, g, ok);
  }
  { int lo = 255, hi = 0, n = 0;
    for (int w = 0; w <= TOP_WINDOW; w++) { int first = -1, last = -1;
      for (int k = 0; k <= 210; k++) if (knobToWindow(k) == w) { if (first < 0) first = k; last = k; }
      int width = last - first + 1; if (width < lo) lo = width; if (width > hi) hi = width; n++; }
    printf("knob readings per note up to 210: %d to %d\n", lo, hi);
    CHECK(lo >= 3, "a note gets only %d readings", lo); }

  // 3. Tuning of every playable note, all three scales, against ideal 24-EDO. The overall
  //    offset is removed first, since fine tune sets that.
  {
    double err[3][TOP_WINDOW + 1], sum = 0; int n = 0;
    for (int c = 0; c < 3; c++) for (int w = 0; w <= TOP_WINDOW; w++) {
      reset(0, 128); root = (c + 1) * 2; lastRoot = root;
      uint8_t q = gridToNote(w); setNote(q);
      err[c][w] = cents(hz(frequency), 65.406 * pow(2.0, (q - 24) / 24.0)); sum += err[c][w]; n++;
    }
    double mean = sum / n, worst = 0;
    printf("\nplayable notes, cents off ideal after removing the %+.1f c overall offset\n", mean);
    for (int c = 0; c < 3; c++) {
      printf("%-12s", NAME[c]);
      for (int w = 0; w <= TOP_WINDOW; w++) { double e = err[c][w] - mean; printf("%+5.1f", e); if (fabs(e) > worst) worst = fabs(e); }
      puts("");
    }
    printf("worst: %.1f cents\n", worst);
    CHECK(worst < 6.0, "a playable note is %.1f cents off", worst);
    reset(0, 128); root = 4; lastRoot = 4;
    setNote(24); double c2 = hz(frequency);
    printf("drone vs melody, cents after the same offset:");
    for (int c = 0; c < 3; c++) { root = (c + 1) * 2; setBass();
      double d = cents(hz(frequency2), 65.406 * pow(2.0, BASS[c] / 12.0)) - mean;
      printf("  %s %+.1f", NAME[c], d); CHECK(fabs(d) < 4.0, "drone %s is %.1f cents from the melody", NAME[c], d); }
    puts("");
    root = 4;
    printf("lowest note %.2f Hz, highest %.1f Hz\n", c2, (setNote(gridToNote(TOP_WINDOW)), hz(frequency)));
    CHECK(fabs(cents(c2, 65.406) - mean) < 6.0, "lowest C off");
  }

  // 4. Bass: right pitch per CHORD, within 4 cents of the melody, and it follows CHORD even with DECAY CCW and the
  //    envelope still ringing (when setNote() never runs).
  for (int c = 0; c < 3; c++) {
    reset(0, 128); step(CHORD_ADC[(c + 1) % 3], 40);
    uint16_t main0 = frequency;
    decayVolume = 255; analogValues[WS_2] = 50;
    step(CHORD_ADC[c], 40, 50);
    // Measured against the melody's own lowest C, not concert pitch: the whole instrument sits
    // a few cents flat until fine tune is set, and that offset applies to both voices.
    uint16_t keepMain = frequency; setNote(24); double ref = hz(frequency); frequency = keepMain;
    double want = ref * pow(2.0, BASS[c] / 12.0);
    CHECK(fabs(cents(hz(frequency2), want)) < 4.0, "%s bass %.2f Hz, want %.2f", NAME[c], hz(frequency2), want);
    printf("%-12s bass %.2f Hz (want %.2f), main held: %s\n", NAME[c], hz(frequency2), want, frequency == main0 ? "yes" : "no");
  }

  // 5. Holding a note must not retrigger the envelope.
  reset(0, 128); step(ADC_OPEN, 100); decayVolume = 0; step(ADC_OPEN, 100);
  CHECK(decayVolume == 0, "held note retriggered");

  // 6. Boot mode: every root (TIMBRE) and NOTE value at three fine-tune settings, with the
  //    memory and math checkers on. Root reaches 13 here, more than the 0-11 kept in EEPROM.
  for (int ws1 = 0; ws1 < 256; ws1++) for (int f : {0, 128, 255}) for (int k = 0; k < 256; k += 3) {
    bootMode = true; analogValues[0] = 200; analogValues[WS_1] = ws1; analogValues[WS_2] = f; pitchAverage = k;
    loop();
    CHECK(transpose <= 13, "boot transpose %d", transpose);
    CHECK(frequency > 0 && frequency2 > 0, "boot zero frequency ws1=%d k=%d", ws1, k);
  }
  bootMode = false;

  printf("\n%s\n", fails ? "RESULT: FAILED" : "RESULT: all checks passed");
  printf("failures: %d\n", fails);
  return fails != 0;
}
