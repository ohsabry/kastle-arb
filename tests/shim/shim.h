// Fake just enough of the ATtiny85 and Arduino to run the sketch on a Mac.
#pragma once
#include <stdint.h>
#include <stdbool.h>
typedef uint8_t byte;
#define PROGMEM
#define pgm_read_byte_near(a) (*(const uint8_t *)(a))
#define pgm_read_word_near(a) (*(const uint16_t *)(a))
#define _BV(b) (1 << (b))
#define bitRead(v, b) (((v) >> (b)) & 1)
#define bitWrite(v, b, x) ((x) ? ((v) |= (1UL << (b))) : ((v) &= ~(1UL << (b))))
#define constrain(x, lo, hi) ((x) < (lo) ? (lo) : ((x) > (hi) ? (hi) : (x)))
#define HIGH 1
#define LOW 0
#define OUTPUT 1
#define ISR(v) void v()
inline long map(long x, long a, long b, long c, long d) { return (x - a) * (d - c) / (b - a) + c; }
inline void digitalWrite(int, int) {}
inline void pinMode(int, int) {}
inline void _delay_us(int) {}
inline void cli() {}
inline void sei() {}
static volatile uint8_t PLLCSR = 0xFF, TCCR0A, TCCR0B, TCCR1, TCNT1, TCNT0, GTCCR, OCR1A, OCR1C,
  TIMSK, OCR0A, OCR0B, ADMUX, ADCSRA, ADCL, ADCH, SREG, DDRB, PORTB;
enum { PLLE, PLOCK, PCKE, LSM, COM0A0, COM0B0, WGM00, WGM02, CS00, PSR1, OCIE1A, CTC1, CS12,
  ADEN, ADPS2, ADPS1, ADPS0, ADIE, ADSC, ADIF, PORTB2, PORTB3, PORTB4, PORTB5 };
struct FakeEEPROM {
  uint8_t m[512];
  uint8_t read(int a) { return m[a]; }
  void write(int a, uint8_t v) { m[a] = v; }
};
static FakeEEPROM EEPROM;
// Arduino's build generates these prototypes automatically.
void sineWave(); void triangleWave(); void squareWave(); void sawtoothWave(); void zeroWave();
void setFrequency(uint16_t); void setFrequency2(uint16_t); void init(); void connectChannel(uint8_t);
void startConversion(); void setup(); void loop(); uint16_t getConversionResult();
