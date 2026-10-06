
//  ecg_internal.h  -  Tipos compartidos entre la adquisicion y el transporte.

#pragma once

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>

#include "ecg.h"

namespace ecg {
namespace internal {

///'E','C' en little-endian. Sirve para que la app resincronice si se pierde.
static constexpr uint16_t kPacketMagic = 0x4345;

enum PacketFlag : uint8_t {
  kFlagLeadsOffPlus   = 1 << 0,  ///< electrodo LO+ despegado
  kFlagLeadsOffMinus  = 1 << 1,  ///< electrodo LO- despegado
  kFlagFiltersSettled = 1 << 2,  ///< los filtros ya convergieron: senal utilizable
  kFlagBpmValid       = 1 << 3,  ///< el campo bpm es confiable
};

// -----------------------------------------------------------------------------
//  Formato de trama binaria (WebSocket, little-endian, 20 bytes de header)
//
//   off  size  campo
//    0    2    magic       0x4345
//    2    1    version     1
//    3    1    flags       ver PacketFlag
//    4    4    seq         contador de paquete, incremental
//    8    4    tMs         millis() de la PRIMERA muestra del paquete
//   12    2    sampleRate  Hz
//   14    2    bpm         0 = desconocido
//   16    2    count       cantidad de muestras que siguen
//   18    2    reserved    0
//   20   2*n   samples     int16 LE, unidades de 0.125 mV
//
//  En la app:  milivolts[i] = samples[i] * 0.125
// -----------------------------------------------------------------------------

#pragma pack(push, 1)
struct PacketHeader {
  uint16_t magic;
  uint8_t  version;
  uint8_t  flags;
  uint32_t seq;
  uint32_t tMs;
  uint16_t sampleRate;
  uint16_t bpm;
  uint16_t count;
  uint16_t reserved;
};
#pragma pack(pop)

static_assert(sizeof(PacketHeader) == 20, "El header debe ocupar 20 bytes exactos");

struct Packet {
  PacketHeader h;
  int16_t      samples[kMaxSamplesPerPacket];

  /// Bytes realmente utiles: header + muestras cargadas.
  size_t byteLength() const {
    return sizeof(PacketHeader) + static_cast<size_t>(h.count) * sizeof(int16_t);
  }
};


//interfaz del transporte (implementada en ecg_stream.cpp)


bool     transportBegin(const Config& cfg, QueueHandle_t queue);
void     transportEnd();
bool     transportWifiConnected();
bool     transportClientConnected();
uint32_t transportPacketsSent();
uint32_t transportPacketsDropped();
int8_t   transportRssi();

///la adquisicion publica aca el estado que el transporte manda en el JSON.
void transportPublishStatus(uint16_t bpm, bool leadsOff, bool settled, bool adcAlive);

}  // namespace internal
}  // namespace ecg
