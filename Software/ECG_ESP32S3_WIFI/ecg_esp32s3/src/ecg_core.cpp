
//  ecg_core.cpp  -  Adquisicion, procesamiento y armado de paquetes.

#include <Arduino.h>
#include <Wire.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include "ecg.h"
#include "ecg_ads1115.h"
#include "ecg_dsp.h"
#include "ecg_internal.h"

namespace ecg {
namespace {

using internal::Packet;
using internal::PacketHeader;

//estado del modulo 
Config          g_cfg;
Ads1115         g_adc;
EcgFilterChain  g_filters;
QrsDetector     g_qrs;

TaskHandle_t    g_samplerTask = nullptr;
QueueHandle_t   g_queue       = nullptr;
bool            g_running     = false;
float           g_lsbMv       = kSampleLsbMillivolts;

//contadores: escritos solo por samplerTask, leidos por otras tareas.
//32 bits alineados en Xtensa -> lectura/escritura atomica de por si.
volatile uint32_t g_samples        = 0;
volatile uint32_t g_missed         = 0;
volatile uint32_t g_i2cErrors      = 0;
volatile bool     g_adcAlive       = false;
volatile bool     g_leadsOff       = false;
volatile bool     g_leadsOffPlus   = false;
volatile bool     g_leadsOffMinus  = false;
volatile bool     g_settled        = false;
volatile uint16_t g_bpm            = 0;

//debounce del leads-off
uint8_t  g_leadsStable   = 0;
uint16_t g_leadsDivider  = 0;

constexpr uint32_t kAdcTimeoutMs      = 250;  // sin RDY por este tiempo -> reintento
constexpr uint8_t  kLeadsStableCount  = 3;    // lecturas coincidentes para aceptar cambio


//ISR: lo minimo indispensable. La lectura I2C va en la tarea, nunca aca.

void IRAM_ATTR onAdcReady() {
  BaseType_t higherPriorityTaskWoken = pdFALSE;
  vTaskNotifyGiveFromISR(g_samplerTask, &higherPriorityTaskWoken);
  if (higherPriorityTaskWoken == pdTRUE) portYIELD_FROM_ISR();
}


//Leads-off del AD8232: los pines LO+ / LO- estan en alto cuando el electrodo
//correspondiente esta despegado. Se muestrean a ~10 Hz con antirrebote.

void updateLeadsOff() {
  const bool plus  = (g_cfg.pinLoPlus  >= 0) && (digitalRead(g_cfg.pinLoPlus)  == HIGH);
  const bool minus = (g_cfg.pinLoMinus >= 0) && (digitalRead(g_cfg.pinLoMinus) == HIGH);
  const bool off   = plus || minus;

  if (off == g_leadsOff) {
    g_leadsStable = 0;
    g_leadsOffPlus  = plus;
    g_leadsOffMinus = minus;
    return;
  }

  if (++g_leadsStable < kLeadsStableCount) return;

  g_leadsStable   = 0;
  g_leadsOff      = off;
  g_leadsOffPlus  = plus;
  g_leadsOffMinus = minus;

  //al reconectar, el offset de continua puede ser otro: recebamos los filtros
  //para no arrastrar un transitorio de varios segundos.
  g_filters.reset();
  g_qrs.reset();
  g_bpm     = 0;
  g_settled = false;
}


// encola el paquete. Si la cola esta llena descartamos el MAS VIEJO: en un
// monitor en vivo interesa lo ultimo, no lo que quedo trabado.

void enqueuePacket(const Packet& pkt) {
  if (g_queue == nullptr) return;

  if (xQueueSend(g_queue, &pkt, 0) != pdTRUE) {
    Packet discarded;
    if (xQueueReceive(g_queue, &discarded, 0) == pdTRUE) {
      xQueueSend(g_queue, &pkt, 0);
    }
  }
}


//tarea de adquisicion

void samplerTask(void*) {
  Packet   pkt{};
  uint32_t seq         = 0;
  uint32_t firstTimeMs = 0;

  pkt.h.magic      = internal::kPacketMagic;
  pkt.h.version    = kProtocolVersion;
  pkt.h.sampleRate = g_cfg.sampleRateHz;
  pkt.h.count      = 0;
  pkt.h.reserved   = 0;

  const uint16_t perPacket =
      (g_cfg.samplesPerPacket > kMaxSamplesPerPacket || g_cfg.samplesPerPacket == 0)
          ? kMaxSamplesPerPacket
          : g_cfg.samplesPerPacket;

  //chequeo de electrodos ~10 veces por segundo.
  const uint16_t leadsEvery = (g_cfg.sampleRateHz / 10) ? (g_cfg.sampleRateHz / 10) : 1;

  const Ads1115::Mux mux = g_cfg.differential ? Ads1115::Mux::DIFF_0_1
                                              : Ads1115::Mux::SINGLE_0;

  for (;;) {
    const uint32_t notifications =
        ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(kAdcTimeoutMs));

    if (notifications == 0) {
      //el ADC dejo de pulsar RDY: cable flojo, glitch de I2C o reset del chip.
      g_adcAlive = false;
      g_adc.startContinuous(mux, Ads1115::Gain::FS_4_096V, g_cfg.sampleRateHz);
      g_filters.reset();
      g_qrs.reset();
      pkt.h.count = 0;
      continue;
    }

    g_adcAlive = true;
    if (notifications > 1) g_missed += (notifications - 1);

    int16_t raw = 0;
    if (!g_adc.readLatest(raw)) {
      ++g_i2cErrors;
      continue;
    }
    ++g_samples;

    const uint32_t nowMs = millis();

    if (++g_leadsDivider >= leadsEvery) {
      g_leadsDivider = 0;
      updateLeadsOff();
    }

    // Procesamiento
    float filteredMv = 0.0f;
    if (!g_leadsOff) {
      filteredMv = g_filters.process(static_cast<float>(raw) * g_lsbMv);
      g_settled  = g_filters.settled();

      if (g_cfg.enableBpm && g_settled) {
        g_qrs.process(filteredMv, nowMs);
        g_bpm = g_qrs.bpm();
      }
    } else {
      //electrodo despegado: mandamos linea plana en vez de basura saturada.
      filteredMv = 0.0f;
      g_settled  = false;
      g_bpm      = 0;
    }

    //cuantizacion a int16 en unidades de LSB 
    int32_t quantized = static_cast<int32_t>(lroundf(filteredMv / g_lsbMv));
    if (quantized > 32767)  quantized = 32767;
    if (quantized < -32768) quantized = -32768;

    if (pkt.h.count == 0) firstTimeMs = nowMs;
    pkt.samples[pkt.h.count++] = static_cast<int16_t>(quantized);

    //cierre de paquete 
    if (pkt.h.count >= perPacket) {
      uint8_t flags = 0;
      if (g_leadsOffPlus)  flags |= internal::kFlagLeadsOffPlus;
      if (g_leadsOffMinus) flags |= internal::kFlagLeadsOffMinus;
      if (g_settled)       flags |= internal::kFlagFiltersSettled;
      if (g_bpm != 0)      flags |= internal::kFlagBpmValid;

      pkt.h.flags = flags;
      pkt.h.seq   = seq++;
      pkt.h.tMs   = firstTimeMs;
      pkt.h.bpm   = g_bpm;

      enqueuePacket(pkt);
      internal::transportPublishStatus(g_bpm, g_leadsOff, g_settled, g_adcAlive);

      pkt.h.count = 0;
    }
  }
}

}  // namespace

//  API publica

bool begin(const Config& cfg) {
  if (g_running) return true;

  g_cfg = cfg;

  if (!Ads1115::isValidSampleRate(g_cfg.sampleRateHz)) {
    log_e("[ECG] sampleRateHz invalido: %u (validos: 8,16,32,64,128,250,475,860)",
          g_cfg.sampleRateHz);
    return false;
  }
  if (g_cfg.pinAdcReady < 0) {
    log_e("[ECG] pinAdcReady es obligatorio: sin ALERT/RDY no hay base de tiempo");
    return false;
  }

  //GPIOs 
  if (g_cfg.pinSdn >= 0) {
    pinMode(g_cfg.pinSdn, OUTPUT);
    digitalWrite(g_cfg.pinSdn, HIGH);  // SDN es activo bajo: HIGH = AD8232 activo
    delay(10);
  }
  if (g_cfg.pinLoPlus  >= 0) pinMode(g_cfg.pinLoPlus,  INPUT);
  if (g_cfg.pinLoMinus >= 0) pinMode(g_cfg.pinLoMinus, INPUT);

  //el ALERT/RDY del ADS1115 es open-drain: necesita pull-up.
  //el interno alcanza para prototipo; para produccion pone 10k a 3V3.
  pinMode(g_cfg.pinAdcReady, INPUT_PULLUP);

  // I2C 
  Wire.begin(g_cfg.pinSda, g_cfg.pinScl, g_cfg.i2cFrequency);
  Wire.setTimeOut(50);  // ms: que un cuelgue del bus no congele la tarea

  if (!g_adc.begin(Wire, g_cfg.adsAddress)) {
    log_e("[ECG] ADS1115 no responde en 0x%02X. Revisa cableado y direccion.",
          g_cfg.adsAddress);
    return false;
  }

  g_lsbMv = Ads1115::lsbMillivolts(Ads1115::Gain::FS_4_096V);

  //  DSP 
  const float fs = static_cast<float>(g_cfg.sampleRateHz);
  g_filters.configure(fs, g_cfg.highPassHz, g_cfg.lowPassHz,
                      g_cfg.mainsHz, g_cfg.enableNotch);
  g_qrs.configure(fs);

  //cola 
  const uint8_t depth = g_cfg.queueDepth ? g_cfg.queueDepth : 8;
  g_queue = xQueueCreate(depth, sizeof(Packet));
  if (g_queue == nullptr) {
    log_e("[ECG] sin memoria para la cola de paquetes");
    return false;
  }

  //  transporte (opcional) 
  if (g_cfg.wifiSsid != nullptr) {
    if (!internal::transportBegin(g_cfg, g_queue)) {
      log_w("[ECG] el transporte WiFi no arranco; sigo muestreando igual");
    }
  }

  //tarea de muestreo 
  const BaseType_t created = xTaskCreatePinnedToCore(
      samplerTask, "ecg_sampler", 4096, nullptr, 5, &g_samplerTask,
      g_cfg.samplerCore);

  if (created != pdPASS || g_samplerTask == nullptr) {
    log_e("[ECG] no pude crear la tarea de muestreo");
    vQueueDelete(g_queue);
    g_queue = nullptr;
    return false;
  }

  //arranque del ADC (recien ahora, con la tarea ya viva) 
  attachInterrupt(digitalPinToInterrupt(g_cfg.pinAdcReady), onAdcReady, FALLING);

  const Ads1115::Mux mux = g_cfg.differential ? Ads1115::Mux::DIFF_0_1
                                              : Ads1115::Mux::SINGLE_0;
  if (!g_adc.startContinuous(mux, Ads1115::Gain::FS_4_096V, g_cfg.sampleRateHz)) {
    log_e("[ECG] fallo la configuracion del modo continuo");
    detachInterrupt(digitalPinToInterrupt(g_cfg.pinAdcReady));
    vTaskDelete(g_samplerTask);
    g_samplerTask = nullptr;
    vQueueDelete(g_queue);
    g_queue = nullptr;
    return false;
  }

  g_running = true;
  log_i("[ECG] corriendo a %u Hz, notch %.0f Hz, %u muestras/paquete",
        g_cfg.sampleRateHz, g_cfg.mainsHz, g_cfg.samplesPerPacket);
  return true;
}

void end() {
  if (!g_running) return;

  detachInterrupt(digitalPinToInterrupt(g_cfg.pinAdcReady));
  g_adc.stop();

  if (g_samplerTask != nullptr) {
    vTaskDelete(g_samplerTask);
    g_samplerTask = nullptr;
  }

  internal::transportEnd();

  if (g_queue != nullptr) {
    vQueueDelete(g_queue);
    g_queue = nullptr;
  }

  if (g_cfg.pinSdn >= 0) digitalWrite(g_cfg.pinSdn, LOW);

  g_running  = false;
  g_adcAlive = false;
}

Status status() {
  Status s;
  s.running         = g_running;
  s.adcAlive        = g_adcAlive;
  s.wifiConnected   = internal::transportWifiConnected();
  s.clientConnected = internal::transportClientConnected();
  s.leadsOff        = g_leadsOff;
  s.leadsOffPlus    = g_leadsOffPlus;
  s.leadsOffMinus   = g_leadsOffMinus;
  s.filtersSettled  = g_settled;
  s.bpm             = g_bpm;
  s.samplesAcquired = g_samples;
  s.samplesMissed   = g_missed;
  s.i2cErrors       = g_i2cErrors;
  s.packetsSent     = internal::transportPacketsSent();
  s.packetsDropped  = internal::transportPacketsDropped();
  s.rssi            = internal::transportRssi();
  return s;
}

uint16_t bpm()      { return g_bpm; }
bool     leadsOff() { return g_leadsOff; }
bool     isRunning(){ return g_running; }

}  // namespace ecg
