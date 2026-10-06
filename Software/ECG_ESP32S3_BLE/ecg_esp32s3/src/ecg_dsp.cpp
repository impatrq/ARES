//filtros digitales y detector de picos R para la senal de ECG del AD8232.

#include "ecg_dsp.h"

#include <math.h>

namespace ecg {

// Biquad

void Biquad::normalize(float b0, float b1, float b2, float a0, float a1, float a2) {
  const float inv = 1.0f / a0;
  b0_ = b0 * inv;
  b1_ = b1 * inv;
  b2_ = b2 * inv;
  a1_ = a1 * inv;
  a2_ = a2 * inv;
  reset();
}

void Biquad::setLowPass(float fs, float fc, float q) {
  const float w0    = 2.0f * PI * (fc / fs);
  const float cosw  = cosf(w0);
  const float alpha = sinf(w0) / (2.0f * q);
  normalize((1.0f - cosw) * 0.5f, 1.0f - cosw, (1.0f - cosw) * 0.5f,
            1.0f + alpha, -2.0f * cosw, 1.0f - alpha);
}

void Biquad::setHighPass(float fs, float fc, float q) {
  const float w0    = 2.0f * PI * (fc / fs);
  const float cosw  = cosf(w0);
  const float alpha = sinf(w0) / (2.0f * q);
  normalize((1.0f + cosw) * 0.5f, -(1.0f + cosw), (1.0f + cosw) * 0.5f,
            1.0f + alpha, -2.0f * cosw, 1.0f - alpha);
}

void Biquad::setNotch(float fs, float f0, float q) {
  const float w0    = 2.0f * PI * (f0 / fs);
  const float cosw  = cosf(w0);
  const float alpha = sinf(w0) / (2.0f * q);
  normalize(1.0f, -2.0f * cosw, 1.0f,
            1.0f + alpha, -2.0f * cosw, 1.0f - alpha);
}

void Biquad::setBandPass(float fs, float f0, float q) {
  const float w0    = 2.0f * PI * (f0 / fs);
  const float cosw  = cosf(w0);
  const float alpha = sinf(w0) / (2.0f * q);
  normalize(alpha, 0.0f, -alpha,
            1.0f + alpha, -2.0f * cosw, 1.0f - alpha);
}

void Biquad::setBypass() {
  b0_ = 1.0f; b1_ = 0.0f; b2_ = 0.0f;
  a1_ = 0.0f; a2_ = 0.0f;
  reset();
}

void Biquad::reset() {
  s1_ = 0.0f;
  s2_ = 0.0f;
}

void Biquad::primeWithDc(float x0) {
  //ganancia en continua del filtro: H(z=1) = (b0+b1+b2) / (1+a1+a2)
  const float den     = 1.0f + a1_ + a2_;
  const float dcGain  = (fabsf(den) < 1e-9f) ? 0.0f : (b0_ + b1_ + b2_) / den;
  const float y0      = dcGain * x0;

  //estados que satisfacen el regimen permanente de la forma directa II
  //transpuesta con entrada constante x0 y salida constante y0.
  s1_ = y0 - b0_ * x0;
  s2_ = b2_ * x0 - a2_ * y0;
}


//  EcgFilterChain


void EcgFilterChain::configure(float sampleRateHz, float highPassHz,
                               float lowPassHz, float mainsHz, bool useNotch) {
  const float nyquist = sampleRateHz * 0.5f;

  highPass_.setHighPass(sampleRateHz, highPassHz);

  //el notch solo tiene sentido si la frecuencia de red esta bien por debajo
  //de Nyquist. A 250 Hz de muestreo, 50 y 60 Hz entran comodos.
  useNotch_ = useNotch && (mainsHz > 0.0f) && (mainsHz < nyquist * 0.9f);
  if (useNotch_) {
    // Q alto = notch angosto: saca la red sin comerse la senal de alrededor.
    notch_.setNotch(sampleRateHz, mainsHz, 30.0f);
  }

  const float lp = (lowPassHz < nyquist * 0.9f) ? lowPassHz : nyquist * 0.9f;
  lowPass_.setLowPass(sampleRateHz, lp);

  settleSamples_ = static_cast<uint32_t>(sampleRateHz);  // 1 segundo
  reset();
}

void EcgFilterChain::reset() {
  highPass_.reset();
  notch_.reset();
  lowPass_.reset();
  primed_      = false;
  settled_     = false;
  sampleCount_ = 0;
}

float EcgFilterChain::process(float millivolts) {
  if (!primed_) {
    //la primera muestra define el nivel DC (la masa virtual del AD8232).
    highPass_.primeWithDc(millivolts);
    notch_.reset();
    lowPass_.reset();
    primed_      = true;
    sampleCount_ = 0;
    settled_     = false;
  }

  float y = highPass_.process(millivolts);
  if (useNotch_) y = notch_.process(y);
  y = lowPass_.process(y);

  if (!settled_ && ++sampleCount_ >= settleSamples_) settled_ = true;
  return y;
}


// QrsDetector

void QrsDetector::configure(float sampleRateHz) {
  sampleRate_ = sampleRateHz;

  //banda 5-15 Hz: es donde vive la energia del complejo QRS y donde menos
  //molestan la onda T (mas lenta) y el ruido muscular (mas rapido).
  bandPassHigh_.setHighPass(sampleRateHz, 5.0f);
  bandPassLow_.setLowPass(sampleRateHz, 15.0f);

  //ventana de integracion de 150 ms: el ancho tipico de un QRS.
  windowLen_ = static_cast<int>(lroundf(0.150f * sampleRateHz));
  if (windowLen_ < 4) windowLen_ = 4;
  if (windowLen_ > kMaxWindow) windowLen_ = kMaxWindow;

  reset();
}

void QrsDetector::reset() {
  bandPassHigh_.reset();
  bandPassLow_.reset();

  for (int i = 0; i < 4; ++i) delay_[i] = 0.0f;
  for (int i = 0; i < kMaxWindow; ++i) window_[i] = 0.0f;

  windowIdx_   = 0;
  windowSum_   = 0.0f;
  spki_        = 0.0f;
  npki_        = 0.0f;
  threshold_   = 0.0f;
  inBurst_     = false;
  burstPeak_   = 0.0f;
  burstPeakMs_ = 0;
  lastBeatMs_  = 0;
  rrCount_     = 0;
  rrIndex_     = 0;
  bpm_         = 0;

  //2 segundos de aprendizaje del piso de ruido antes de declarar latidos.
  warmupSamples_ = static_cast<uint32_t>(sampleRate_ * 2.0f);
}

bool QrsDetector::process(float x, uint32_t nowMs) {
  //Bandpass 5-15 Hz 
  const float band = bandPassLow_.process(bandPassHigh_.process(x));

  //derivada de 5 puntos: y = (2x[n] + x[n-1] - x[n-3] - 2x[n-4]) / 8 --
  const float deriv = (2.0f * band + delay_[0] - delay_[2] - 2.0f * delay_[3]) * 0.125f;
  delay_[3] = delay_[2];
  delay_[2] = delay_[1];
  delay_[1] = delay_[0];
  delay_[0] = band;

  //cuadrado: todo positivo y realza las pendientes fuertes -----------
  const float squared = deriv * deriv;

  //integracion de ventana movil 
  windowSum_ -= window_[windowIdx_];
  window_[windowIdx_] = squared;
  windowSum_ += squared;
  windowIdx_ = (windowIdx_ + 1) % windowLen_;
  if (windowSum_ < 0.0f) windowSum_ = 0.0f;  // guarda contra deriva numerica
  const float integrated = windowSum_ / static_cast<float>(windowLen_);

  //si hace rato que no hay latidos, el BPM deja de ser confiable.
  if (lastBeatMs_ != 0 && (nowMs - lastBeatMs_) > 3000u) {
    bpm_     = 0;
    rrCount_ = 0;
    rrIndex_ = 0;
  }

  //aprendizaje inicial del piso de ruido 
  if (warmupSamples_ > 0) {
    --warmupSamples_;
    npki_      = 0.98f * npki_ + 0.02f * integrated;
    threshold_ = npki_ * 4.0f;
    return false;
  }

  //umbral adaptativo 
  bool beat = false;

  if (!inBurst_) {
    if (integrated > threshold_ && threshold_ > 0.0f) {
      inBurst_     = true;
      burstPeak_   = integrated;
      burstPeakMs_ = nowMs;
    } else {
      npki_ = 0.875f * npki_ + 0.125f * integrated;
    }
  } else {
    if (integrated > burstPeak_) {
      burstPeak_   = integrated;
      burstPeakMs_ = nowMs;  // el latido se marca en el pico, no en el cruce
    }
    //salimos del burst con histeresis para no rebotar sobre el umbral.
    if (integrated < threshold_ * 0.5f) {
      inBurst_ = false;
      if (lastBeatMs_ == 0 || (burstPeakMs_ - lastBeatMs_) >= refractoryMs_) {
        spki_ = 0.875f * spki_ + 0.125f * burstPeak_;
        registerBeat(burstPeakMs_);
        beat = true;
      }
    }
  }

  threshold_ = npki_ + 0.25f * (spki_ - npki_);
  return beat;
}

void QrsDetector::registerBeat(uint32_t beatMs) {
  if (lastBeatMs_ != 0) {
    const uint32_t rr = beatMs - lastBeatMs_;
    //250-2000 ms equivale a 30-240 bpm. Fuera de eso es artefacto.
    if (rr >= 250u && rr <= 2000u) {
      rr_[rrIndex_] = static_cast<uint16_t>(rr);
      rrIndex_      = (rrIndex_ + 1) % 8;
      if (rrCount_ < 8) ++rrCount_;

      uint32_t sum = 0;
      for (uint8_t i = 0; i < rrCount_; ++i) sum += rr_[i];
      const float meanRr = static_cast<float>(sum) / static_cast<float>(rrCount_);
      if (meanRr > 1.0f) {
        bpm_ = static_cast<uint16_t>(lroundf(60000.0f / meanRr));
      }
    }
  }
  lastBeatMs_ = beatMs;
}

}  // namespace ecg
