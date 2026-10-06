//CONTROLADOR DEL ADC ADS1115, usado para leer la salida del AD8232.

#include "ecg_ads1115.h"

namespace ecg {
namespace {

//punteros de registro del ADS1115
constexpr uint8_t kRegConversion = 0x00;
constexpr uint8_t kRegConfig     = 0x01;
constexpr uint8_t kRegLoThresh   = 0x02;
constexpr uint8_t kRegHiThresh   = 0x03;

//bits del registro CONFIG
constexpr uint16_t kOsSingle       = 0x8000;  // OS=1: dispara conversion
constexpr uint16_t kModeContinuous = 0x0000;  // bit 8 = 0
constexpr uint16_t kModeSingleShot = 0x0100;  // bit 8 = 1
constexpr uint16_t kCompQueDisable = 0x0003;  // COMP_QUE=11: ALERT/RDY en alta Z
//COMP_QUE=00 (assert tras 1 conversion) es lo que habilita el modo RDY.
constexpr uint16_t kCompQue1Conv   = 0x0000;

//fondos de escala en milivolts, indexados por Gain.
constexpr float kFullScaleMv[6] = {6144.0f, 4096.0f, 2048.0f, 1024.0f, 512.0f, 256.0f};

constexpr uint16_t kValidRates[8] = {8, 16, 32, 64, 128, 250, 475, 860};

}  // namespace

bool Ads1115::isValidSampleRate(uint16_t sampleRateHz) {
  for (uint16_t r : kValidRates) {
    if (r == sampleRateHz) return true;
  }
  return false;
}

uint8_t Ads1115::sampleRateCode(uint16_t sampleRateHz) {
  for (uint8_t i = 0; i < 8; ++i) {
    if (kValidRates[i] == sampleRateHz) return i;
  }
  return 4;  // 128 SPS: default seguro del chip
}

float Ads1115::lsbMillivolts(Gain gain) {
  const uint8_t idx = static_cast<uint8_t>(gain);
  if (idx > 5) return kFullScaleMv[1] / 32768.0f;
  return kFullScaleMv[idx] / 32768.0f;
}

bool Ads1115::begin(TwoWire& wire, uint8_t address) {
  wire_                = &wire;
  address_             = address;
  pointerOnConversion_ = false;

  uint16_t dummy = 0;
  return readRegister(kRegConfig, dummy);
}

bool Ads1115::startContinuous(Mux mux, Gain gain, uint16_t sampleRateHz) {
  if (wire_ == nullptr) return false;
  if (!isValidSampleRate(sampleRateHz)) return false;

  gain_                = gain;
  pointerOnConversion_ = false;

  //modo "conversion ready" del pin ALERT/RDY: MSB del threshold alto en 1 y
  //MSB del threshold bajo en 0. Sin esto el pin funciona como comparador y no
  //pulsa por cada muestra.
  if (!writeRegister(kRegHiThresh, 0x8000)) return false;
  if (!writeRegister(kRegLoThresh, 0x0000)) return false;

  uint16_t config = 0;
  config |= kOsSingle;                                       // arranca la primera conversion
  config |= static_cast<uint16_t>(mux);                      // MUX[14:12]
  config |= (static_cast<uint16_t>(gain) & 0x07) << 9;       // PGA[11:9]
  config |= kModeContinuous;                                 // MODE[8]
  config |= (sampleRateCode(sampleRateHz) & 0x07) << 5;      // DR[7:5]
  //COMP_MODE[4]=0 comparador tradicional
  //COMP_POL[3]=0  ALERT/RDY activo en bajo  -> interrupcion por flanco de bajada
  //COMP_LAT[2]=0  no latcheado
  config |= kCompQue1Conv; // COMP_QUE[1:0]

  if (!writeRegister(kRegConfig, config)) return false;

  //dejamos el puntero en el registro de conversion: de aca en mas cada muestra
  //cuesta solo una lectura de 2 bytes (~60 us a 400 kHz).
  return setPointer(kRegConversion);
}

bool Ads1115::stop() {
  if (wire_ == nullptr) return false;
  pointerOnConversion_ = false;

  uint16_t config = 0;
  config |= static_cast<uint16_t>(Mux::SINGLE_0);
  config |= (static_cast<uint16_t>(gain_) & 0x07) << 9;
  config |= kModeSingleShot;
  config |= kCompQueDisable;
  return writeRegister(kRegConfig, config);
}

bool Ads1115::readLatest(int16_t& out) {
  if (wire_ == nullptr) return false;

  if (!pointerOnConversion_ && !setPointer(kRegConversion)) return false;

  const uint8_t received = wire_->requestFrom(static_cast<uint16_t>(address_),
                                              static_cast<uint8_t>(2));
  if (received != 2) {
    pointerOnConversion_ = false;  //forzamos reposicionar el puntero
    return false;
  }

  const uint8_t hi = static_cast<uint8_t>(wire_->read());
  const uint8_t lo = static_cast<uint8_t>(wire_->read());
  out = static_cast<int16_t>((static_cast<uint16_t>(hi) << 8) | lo);
  return true;
}

bool Ads1115::writeRegister(uint8_t reg, uint16_t value) {
  wire_->beginTransmission(address_);
  wire_->write(reg);
  wire_->write(static_cast<uint8_t>(value >> 8));
  wire_->write(static_cast<uint8_t>(value & 0xFF));
  pointerOnConversion_ = false;
  return wire_->endTransmission() == 0;
}

bool Ads1115::readRegister(uint8_t reg, uint16_t& value) {
  if (!setPointer(reg)) return false;
  if (wire_->requestFrom(static_cast<uint16_t>(address_),
                         static_cast<uint8_t>(2)) != 2) {
    return false;
  }
  const uint8_t hi = static_cast<uint8_t>(wire_->read());
  const uint8_t lo = static_cast<uint8_t>(wire_->read());
  value = (static_cast<uint16_t>(hi) << 8) | lo;
  return true;
}

bool Ads1115::setPointer(uint8_t reg) {
  wire_->beginTransmission(address_);
  wire_->write(reg);
  const bool ok        = (wire_->endTransmission() == 0);
  pointerOnConversion_ = ok && (reg == kRegConversion);
  return ok;
}

}  // namespace ecg
