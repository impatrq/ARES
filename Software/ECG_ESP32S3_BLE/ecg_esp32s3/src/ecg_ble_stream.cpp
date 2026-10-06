// Transporte BLE (NimBLE-Arduino 1.4.x) para el monitor ECG.
//
//  - 0x0003 (NOTIFY): stream de ECG en BINARIO, int16 little-endian, en unidades
//    de LSB del ADS1115 (0.125 mV a +-4.096 V). Notificaciones de <= 20 bytes
//    (10 muestras) para que entren en el MTU por defecto de BLE (Android e iOS).
//  - 0x0002 (READ|NOTIFY): estado en JSON {"bpm":N,"leadsOff":true|false},
//    publicado a 1 Hz desde la tarea BLE (no desde la tarea de muestreo).

#include <Arduino.h>
#include <NimBLEDevice.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include "ecg_internal.h"

namespace ecg {
namespace internal {
namespace {

#define SERVICE_UUID         "6b6f0001-8c37-4d5a-9b1a-1e2c9f6d1a10"
#define CHAR_STATUS_UUID     "6b6f0002-8c37-4d5a-9b1a-1e2c9f6d1a10"
#define CHAR_ECG_STREAM_UUID "6b6f0003-8c37-4d5a-9b1a-1e2c9f6d1a10"

constexpr size_t   kMaxNotifyBytes = 20;    // MTU 23 - 3 de cabecera ATT
constexpr uint32_t kStatusPeriodMs = 1000;  // estado a 1 Hz

NimBLEServer*         g_server          = nullptr;
NimBLECharacteristic* pCharStatus       = nullptr;
NimBLECharacteristic* pCharStream       = nullptr;
QueueHandle_t         g_queue           = nullptr;
TaskHandle_t          g_task            = nullptr;
bool                  g_running         = false;
volatile bool         g_deviceConnected = false;

volatile uint32_t g_sent    = 0;
volatile uint32_t g_dropped = 0;

// Ultimo estado, escrito por samplerTask y leido por transportTask.
volatile uint16_t g_lastBpm      = 0;
volatile bool     g_lastLeadsOff = true;

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer, ble_gap_conn_desc* desc) override {
        g_deviceConnected = true;
        // Intervalo de conexion 15-30 ms (unidades de 1.25 ms), timeout 2 s.
        pServer->updateConnParams(desc->conn_handle, 12, 24, 0, 200);
        Serial.println("[BLE] App conectada.");
    }

    void onDisconnect(NimBLEServer* pServer) override {
        g_deviceConnected = false;
        Serial.println("[BLE] App desconectada. Reiniciando advertising...");
        NimBLEDevice::startAdvertising();
    }
};

// Envia las muestras en trozos de <= 20 bytes (siempre multiplo de 2).
void sendSamples(const int16_t* samples, uint8_t count) {
    const uint8_t* bytes = reinterpret_cast<const uint8_t*>(samples);
    const size_t   total = static_cast<size_t>(count) * sizeof(int16_t);
    size_t offset = 0;

    while (offset < total) {
        const size_t n = (total - offset < kMaxNotifyBytes) ? (total - offset)
                                                            : kMaxNotifyBytes;
        pCharStream->setValue(bytes + offset, n);
        pCharStream->notify();
        offset += n;
    }
    ++g_sent;
}

void publishStatusNow() {
    char json[48];
    snprintf(json, sizeof(json), "{\"bpm\":%u,\"leadsOff\":%s}",
             static_cast<unsigned>(g_lastBpm), g_lastLeadsOff ? "true" : "false");
    pCharStatus->setValue(reinterpret_cast<const uint8_t*>(json), strlen(json));
    if (g_deviceConnected) pCharStatus->notify();
}

void transportTask(void*) {
    Packet   pkt;
    uint32_t lastStatusMs = 0;

    for (;;) {
        if (xQueueReceive(g_queue, &pkt, pdMS_TO_TICKS(100)) == pdTRUE) {
            if (g_deviceConnected && pCharStream != nullptr) {
                sendSamples(pkt.samples, pkt.h.count);
            } else {
                ++g_dropped;  // sin app conectada: se descarta
            }
        }

        const uint32_t now = millis();
        if (now - lastStatusMs >= kStatusPeriodMs) {
            lastStatusMs = now;
            publishStatusNow();
        }
    }
}

}  // namespace

bool transportBegin(const Config& cfg, QueueHandle_t queue) {
    if (g_running) return true;
    g_queue = queue;

    NimBLEDevice::init("ARES-CardiacMonitor");
    NimBLEDevice::setPower(ESP_PWR_LVL_P9);

    g_server = NimBLEDevice::createServer();
    g_server->setCallbacks(new ServerCallbacks());

    NimBLEService* pService = g_server->createService(SERVICE_UUID);

    pCharStatus = pService->createCharacteristic(
        CHAR_STATUS_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
    pCharStatus->setValue("{\"bpm\":0,\"leadsOff\":true}");

    pCharStream = pService->createCharacteristic(
        CHAR_ECG_STREAM_UUID, NIMBLE_PROPERTY::NOTIFY);

    pService->start();

    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);   // el nombre va en el scan response
    pAdvertising->setMinPreferred(0x06);   // ayuda a la conexion en iOS
    pAdvertising->setMaxPreferred(0x12);
    pAdvertising->start();
    Serial.println("[BLE] NimBLE y advertising listos.");

    xTaskCreatePinnedToCore(transportTask, "ecg_ble_tx", 6144, nullptr, 3,
                            &g_task, cfg.transportCore);
    g_running = true;
    return true;
}

void transportEnd() {
    if (!g_running) return;
    if (g_task != nullptr) { vTaskDelete(g_task); g_task = nullptr; }
    NimBLEDevice::deinit(true);
    g_running         = false;
    g_deviceConnected = false;
}

bool     transportWifiConnected()   { return true; }  // no se usa WiFi
bool     transportClientConnected() { return g_deviceConnected; }
uint32_t transportPacketsSent()     { return g_sent; }
uint32_t transportPacketsDropped()  { return g_dropped; }
int8_t   transportRssi()            { return 0; }

// Se llama desde samplerTask: SOLO guarda valores, no toca el stack BLE.
void transportPublishStatus(uint16_t bpmValue, bool leadsOff, bool /*settled*/, bool /*adcAlive*/) {
    g_lastBpm      = bpmValue;
    g_lastLeadsOff = leadsOff;
}

}  // namespace internal
}  // namespace ecg
