//  ecg_dsp.h  -  Filtrado y deteccion de QRS.



#pragma once

#include <Arduino.h>

namespace ecg {

  //  Biquad (coeficientes segun el "Audio EQ Cookbook" de RBJ)

class Biquad {
 public:
  void setLowPass(float fs, float fc, float q = 0.70710678f);
  void setHighPass(float fs, float fc, float q = 0.70710678f);
  void setNotch(float fs, float f0, float q = 30.0f);
  void setBandPass(float fs, float f0, float q);
  void setBypass();

  void reset();

  ///precarga los estados internos para que la salida arranque directamente en
  ///su valor de regimen permanente frente a una entrada constante x0.
  ///para un pasaalto eso significa salida = 0 desde la primera muestra, o sea
  ///cero transitorio de arranque en vez de varios segundos de deriva.
  void primeWithDc(float x0);

  inline float process(float x) {
    const float y = b0_ * x + s1_;
    s1_ = b1_ * x - a1_ * y + s2_;
    s2_ = b2_ * x - a2_ * y;
    return y;
  }

 private:
  void normalize(float b0, float b1, float b2, float a0, float a1, float a2);

  float b0_ = 1.0f, b1_ = 0.0f, b2_ = 0.0f;
  float a1_ = 0.0f, a2_ = 0.0f;
  float s1_ = 0.0f, s2_ = 0.0f;
};


//cadena de acondicionamiento: pasaalto -> notch de red -> pasabajo

class EcgFilterChain {
 public:
  void configure(float sampleRateHz, float highPassHz, float lowPassHz,
                 float mainsHz, bool useNotch);

  ///vuelve al estado "sin cebar": la proxima muestra define el nuevo nivel DC.
  ///se llama cuando se despega un electrodo, porque al reconectarlo el offset
  ///puede haber cambiado por completo.
  void reset();

  ///entrada en milivolts crudos (con el offset de ~1650 mV incluido).
  ///salida en milivolts centrados en cero.
  float process(float millivolts);

  bool settled() const { return settled_; }

 private:
  Biquad   highPass_;
  Biquad   notch_;
  Biquad   lowPass_;
  bool     useNotch_      = true;
  bool     primed_        = false;
  bool     settled_       = false;
  uint32_t sampleCount_   = 0;
  uint32_t settleSamples_ = 250;
};


//detector de QRS: Pan-Tompkins simplificado

class QrsDetector {
 public:
  void configure(float sampleRateHz);
  void reset();

  ///x = muestra ya filtrada (mV). Devuelve true en la muestra donde cierra un
  ///complejo QRS valido.
  bool process(float x, uint32_t nowMs);

  uint16_t bpm() const { return bpm_; }
  bool     bpmValid() const { return bpm_ != 0; }

 private:
  void registerBeat(uint32_t beatMs);

  static constexpr int kMaxWindow = 128;

  Biquad   bandPassHigh_;   // 5 Hz  pasaalto
  Biquad   bandPassLow_;    // 15 Hz pasabajo
  float    delay_[4]        = {0.0f, 0.0f, 0.0f, 0.0f};  // memoria de la derivada
  float    window_[kMaxWindow] = {0.0f};
  int      windowLen_       = 37;
  int      windowIdx_       = 0;
  float    windowSum_       = 0.0f;

  float    spki_            = 0.0f;   // estimacion de pico de senal
  float    npki_            = 0.0f;   // estimacion de pico de ruido
  float    threshold_       = 0.0f;
  bool     inBurst_         = false;
  float    burstPeak_       = 0.0f;
  uint32_t burstPeakMs_     = 0;

  uint32_t lastBeatMs_      = 0;
  uint32_t refractoryMs_    = 220;
  uint32_t warmupSamples_   = 0;

  uint16_t rr_[8]           = {0};
  uint8_t  rrCount_         = 0;
  uint8_t  rrIndex_         = 0;
  uint16_t bpm_             = 0;

  float    sampleRate_      = 250.0f;
};

}  // namespace ecg
