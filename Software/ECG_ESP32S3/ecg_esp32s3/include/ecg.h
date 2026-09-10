
//  ecg.h  -  API publica del modulo de ECG (ESP32-S3 + AD8232 + ADS1115)

#pragma once

#include <stdint.h>
#include <stddef.h>

namespace ecg {


//constantes del formato de datos que viaja por WiFi


///valor de 1 LSB de las muestras transmitidas, en milivolts.
///coincide con el LSB del ADS1115 con PGA en +/-4.096 V (4096 mV / 32768).
///en la app: milivolts = muestra_int16 * 0.125f
static constexpr float kSampleLsbMillivolts = 0.125f;

///tope de muestras que entran en un paquete (limita el tamano de la cola).
static constexpr uint16_t kMaxSamplesPerPacket = 64;

///version del protocolo binario (campo `version` del header).
static constexpr uint8_t kProtocolVersion = 1;


//configuracion


struct Config {
  //Bus I2C / ADS1115 
  int      pinSda        = 8;        ///< SDA hacia el ADS1115
  int      pinScl        = 9;        ///< SCL hacia el ADS1115
  uint32_t i2cFrequency  = 400000;   ///< 400 kHz (fast mode)
  uint8_t  adsAddress    = 0x48;     ///< ADDR a GND=0x48, VDD=0x49, SDA=0x4A, SCL=0x4B
  int      pinAdcReady   = 4;        ///< ALERT/RDY del ADS1115. OBLIGATORIO.
                                     ///< Necesita pull-up a 3V3 (10k externo recomendado).

  // AD8232 
  int      pinLoPlus     = 5;        ///< LO+  (HIGH = electrodo desconectado). -1 si no se usa
  int      pinLoMinus    = 6;        ///< LO-  (HIGH = electrodo desconectado). -1 si no se usa
  int      pinSdn        = -1;       ///< SDN (activo bajo). -1 si esta cableado a 3V3

  //  Adquisicion
  ///tasas validas del ADS1115: 8, 16, 32, 64, 128, 250, 475, 860.
  ///250 Hz es el punto dulce para ECG: cumple con el ancho de banda util
  ///(0.5-40 Hz) con margen de sobra y deja tiempo de I2C libre.
  uint16_t sampleRateHz  = 250;

  ///false -> AIN0 single-ended (OUTPUT del AD8232 directo a AIN0).
  ///true  -> diferencial AIN0-AIN1 (AIN1 a una referencia de medio riel).
  ///mejor rechazo de ruido de la fuente, pero requiere esa referencia.
  bool     differential  = false;

  //procesamiento 
  float    mainsHz       = 50.0f;    ///< 50 en AR/EU, 60 en US/BR. Frecuencia del notch
  float    highPassHz    = 0.5f;     ///< corta la deriva de linea de base
  float    lowPassHz     = 40.0f;    ///< modo monitor. Subilo a 100-150 para modo diagnostico
  bool     enableNotch   = true;
  bool     enableBpm     = true;     ///< detector QRS / calculo de BPM

  //red 
  const char* wifiSsid   = nullptr;  ///< nullptr = no arranca el transporte WiFi
  const char* wifiPass   = nullptr;
  const char* hostname   = "esp32-ecg";  ///< tambien usado para mDNS: esp32-ecg.local
  uint16_t    httpPort   = 80;
  uint16_t    samplesPerPacket = 25; ///< 25 @ 250 Hz = 1 paquete cada 100 ms
  uint8_t     queueDepth = 10;       ///< paquetes en vuelo antes de descartar

  //tareas 
  int      samplerCore   = 1;        ///< core del muestreo (1 = lejos del stack WiFi)
  int      transportCore = 0;
};

// Estado

struct Status {
  bool     running          = false;
  bool     adcAlive         = false;  ///< false si el ADS1115 dejo de pulsar RDY
  bool     wifiConnected    = false;
  bool     clientConnected  = false;  ///< hay al menos un cliente WebSocket
  bool     leadsOff         = false;  ///< algun electrodo despegado
  bool     leadsOffPlus     = false;
  bool     leadsOffMinus    = false;
  bool     filtersSettled   = false;  ///< los filtros ya convergieron
  uint16_t bpm              = 0;      ///< 0 = todavia sin lectura confiable
  uint32_t samplesAcquired  = 0;
  uint32_t samplesMissed    = 0;      ///< conversiones perdidas (tarea llego tarde)
  uint32_t i2cErrors        = 0;
  uint32_t packetsSent      = 0;
  uint32_t packetsDropped   = 0;
  int8_t   rssi             = 0;
};

// API

///inicializa I2C, ADS1115, GPIOs del AD8232, filtros, WiFi y tareas.
///devuelve false si el ADC no responde o la configuracion es invalida.
bool begin(const Config& cfg);

///detiene tareas, libera la interrupcion y deja el ADC en bajo consumo.
void end();

///snapshot consistente del estado actual.
Status status();

///atajos de conveniencia.
uint16_t bpm();
bool leadsOff();
bool isRunning();

}  // namespace ecg
