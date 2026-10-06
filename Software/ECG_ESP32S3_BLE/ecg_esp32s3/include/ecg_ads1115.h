
//ecg_ads1115.h  -  Driver minimo del ADS1115 orientado a muestreo continuo.

#pragma once
#include <SPI.h>
#include <Arduino.h>
#include <Wire.h>

namespace ecg {

class Ads1115 {
 public:
  ///rango de entrada del PGA. Con la salida del AD8232 montada sobre ~1.65 V
  ///y medida single-ended, el unico rango que no satura es +/-4.096 V.
  enum class Gain : uint8_t {
    FS_6_144V = 0,
    FS_4_096V = 1,
    FS_2_048V = 2,
    FS_1_024V = 3,
    FS_0_512V = 4,
    FS_0_256V = 5,
  };

  ///valores ya desplazados a la posicion de MUX[14:12] del registro CONFIG.
  enum class Mux : uint16_t {
    DIFF_0_1 = 0x0000,
    DIFF_0_3 = 0x1000,
    DIFF_1_3 = 0x2000,
    DIFF_2_3 = 0x3000,
    SINGLE_0 = 0x4000,
    SINGLE_1 = 0x5000,
    SINGLE_2 = 0x6000,
    SINGLE_3 = 0x7000,
  };

  ///verifica presencia leyendo el registro de configuracion.
  bool begin(TwoWire& wire, uint8_t address);

  ///deja el ADC convirtiendo sin parar y ALERT/RDY pulsando por cada muestra.
  bool startContinuous(Mux mux, Gain gain, uint16_t sampleRateHz);

  ///vuelve a single-shot (bajo consumo) y desactiva ALERT/RDY.
  bool stop();

  ///lectura rapida: 2 bytes, sin reescribir el puntero.
  ///en modo continuo el registro de conversion siempre tiene la ultima muestra.
  bool readLatest(int16_t& out);

  /// Milivolts por LSB para el rango dado (32768 pasos por fondo de escala).
  static float lsbMillivolts(Gain gain);

  static bool isValidSampleRate(uint16_t sampleRateHz);

 private:
  bool writeRegister(uint8_t reg, uint16_t value);
  bool readRegister(uint8_t reg, uint16_t& value);
  bool setPointer(uint8_t reg);
  static uint8_t sampleRateCode(uint16_t sampleRateHz);

  TwoWire* wire_                = nullptr;
  uint8_t  address_             = 0x48;
  Gain     gain_                = Gain::FS_4_096V;
  bool     pointerOnConversion_ = false;
};

}  // namespace ecg
