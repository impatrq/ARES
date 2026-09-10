// Transporte WiFi por WebSocket.
//
// Endpoints:
//     ws://<ip>/ecg     tramas binarias con las muestras + JSON de estado (1 Hz)
//     http://<ip>/status  JSON de estado (para debug rapido con curl)


#include <Arduino.h>
#include <ESPAsyncWebServer.h>
#include <ESPmDNS.h>
#include <WiFi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>

#include "ecg_internal.h"

namespace ecg {
namespace internal {
namespace {

AsyncWebServer*   g_server  = nullptr;
AsyncWebSocket*   g_ws      = nullptr;
QueueHandle_t     g_queue   = nullptr;
TaskHandle_t      g_task    = nullptr;
bool              g_running = false;

char     g_ssid[64]     = {0};
char     g_pass[72]     = {0};
char     g_hostname[32] = {0};
uint16_t g_port         = 80;

volatile uint32_t g_sent    = 0;
volatile uint32_t g_dropped = 0;
volatile uint32_t g_clients = 0;

//estado publicado por la tarea de adquisicion
volatile uint16_t g_bpm      = 0;
volatile bool     g_leadsOff = false;
volatile bool     g_settled  = false;
volatile bool     g_adcAlive = false;

uint32_t g_lastWifiAttemptMs = 0;
bool     g_mdnsStarted       = false;

constexpr uint32_t kWifiRetryMs = 5000;


size_t buildStatusJson(char* buffer, size_t size) {
  return snprintf(
      buffer, size,
      "{\"type\":\"status\",\"bpm\":%u,\"leadsOff\":%s,\"settled\":%s,"
      "\"adcAlive\":%s,\"clients\":%u,\"sent\":%u,\"dropped\":%u,"
      "\"rssi\":%d,\"uptimeMs\":%u,\"heap\":%u}",
      static_cast<unsigned>(g_bpm),
      g_leadsOff ? "true" : "false",
      g_settled  ? "true" : "false",
      g_adcAlive ? "true" : "false",
      static_cast<unsigned>(g_clients),
      static_cast<unsigned>(g_sent),
      static_cast<unsigned>(g_dropped),
      static_cast<int>(WiFi.isConnected() ? WiFi.RSSI() : 0),
      static_cast<unsigned>(millis()),
      static_cast<unsigned>(ESP.getFreeHeap()));
}


void onWebSocketEvent(AsyncWebSocket* server, AsyncWebSocketClient* client,
                      AwsEventType type, void* arg, uint8_t* data, size_t len) {
  (void)server; (void)arg; (void)data; (void)len;

  switch (type) {
    case WS_EVT_CONNECT:
      ++g_clients;
      log_i("[ECG] cliente WS #%u conectado desde %s",
            client->id(), client->remoteIP().toString().c_str());
      break;

    case WS_EVT_DISCONNECT:
      if (g_clients > 0) --g_clients;
      log_i("[ECG] cliente WS desconectado");
      break;

    case WS_EVT_ERROR:
      log_w("[ECG] error en el WebSocket");
      break;

    default:
      break;
  }
}


void ensureWifi() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!g_mdnsStarted && g_hostname[0] != '\0') {
      if (MDNS.begin(g_hostname)) {
        MDNS.addService("http", "tcp", g_port);
        g_mdnsStarted = true;
        log_i("[ECG] mDNS activo: http://%s.local", g_hostname);
      }
    }
    return;
  }

  g_mdnsStarted = false;

  const uint32_t now = millis();
  if (now - g_lastWifiAttemptMs < kWifiRetryMs) return;
  g_lastWifiAttemptMs = now;

  log_w("[ECG] reconectando WiFi...");
  WiFi.disconnect();
  WiFi.begin(g_ssid, g_pass);
}


void transportTask(void*) {
  uint32_t lastStatusMs = 0;
  char     json[256];
  Packet   pkt;

  for (;;) {
    ensureWifi();

    if (g_ws != nullptr) g_ws->cleanupClients();

    //vaciamos la cola en cada vuelta. El timeout de 20 ms es el que le da
    //ritmo a la tarea cuando no hay datos.
    while (xQueueReceive(g_queue, &pkt, pdMS_TO_TICKS(20)) == pdTRUE) {
      if (g_ws == nullptr || g_ws->count() == 0) {
        ++g_dropped;  // nadie escuchando
        continue;
      }
      //contrapresion: si el buffer TCP esta lleno, tiramos el paquete en vez
      //de encolar sin control y quedarnos sin heap.
      if (!g_ws->availableForWriteAll()) {
        ++g_dropped;
        continue;
      }
      g_ws->binaryAll(reinterpret_cast<const char*>(&pkt), pkt.byteLength());
      ++g_sent;
    }

    const uint32_t now = millis();
    if (now - lastStatusMs >= 1000) {
      lastStatusMs = now;
      if (g_ws != nullptr && g_ws->count() > 0 && g_ws->availableForWriteAll()) {
        const size_t n = buildStatusJson(json, sizeof(json));
        g_ws->textAll(json, n);
      }
    }
  }
}

}  // namespace


bool transportBegin(const Config& cfg, QueueHandle_t queue) {
  if (g_running) return true;
  if (cfg.wifiSsid == nullptr) return false;

  g_queue = queue;
  g_port  = cfg.httpPort;

  strncpy(g_ssid, cfg.wifiSsid, sizeof(g_ssid) - 1);
  if (cfg.wifiPass != nullptr) strncpy(g_pass, cfg.wifiPass, sizeof(g_pass) - 1);
  if (cfg.hostname != nullptr) strncpy(g_hostname, cfg.hostname, sizeof(g_hostname) - 1);

  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  if (g_hostname[0] != '\0') WiFi.setHostname(g_hostname);
  //sin esto el modem duerme entre beacons y te mete picos de latencia de
  //cientos de ms en el streaming.
  WiFi.setSleep(false);
  WiFi.setAutoReconnect(true);
  WiFi.begin(g_ssid, g_pass);
  g_lastWifiAttemptMs = millis();

  g_server = new AsyncWebServer(g_port);
  g_ws     = new AsyncWebSocket("/ecg");
  if (g_server == nullptr || g_ws == nullptr) {
    log_e("[ECG] sin memoria para el servidor");
    return false;
  }

  g_ws->onEvent(onWebSocketEvent);
  g_server->addHandler(g_ws);

  g_server->on("/status", HTTP_GET, [](AsyncWebServerRequest* request) {
    char json[256];
    const size_t n = buildStatusJson(json, sizeof(json));
    (void)n;
    request->send(200, "application/json", json);
  });

  g_server->onNotFound([](AsyncWebServerRequest* request) {
    request->send(404, "text/plain", "ECG: usa ws://<ip>/ecg o GET /status");
  });

  g_server->begin();

  const BaseType_t created = xTaskCreatePinnedToCore(
      transportTask, "ecg_tx", 6144, nullptr, 3, &g_task, cfg.transportCore);

  if (created != pdPASS) {
    log_e("[ECG] no pude crear la tarea de transporte");
    return false;
  }

  g_running = true;
  return true;
}

void transportEnd() {
  if (!g_running) return;

  if (g_task != nullptr) {
    vTaskDelete(g_task);
    g_task = nullptr;
  }
  if (g_ws != nullptr) {
    g_ws->closeAll();
  }
  if (g_server != nullptr) {
    g_server->end();
    delete g_server;
    g_server = nullptr;
  }
  if (g_ws != nullptr) {
    delete g_ws;
    g_ws = nullptr;
  }

  WiFi.disconnect(true);
  g_running     = false;
  g_clients     = 0;
  g_mdnsStarted = false;
}

bool     transportWifiConnected()   { return WiFi.status() == WL_CONNECTED; }
bool     transportClientConnected() { return g_clients > 0; }
uint32_t transportPacketsSent()     { return g_sent; }
uint32_t transportPacketsDropped()  { return g_dropped; }
int8_t   transportRssi() {
  return WiFi.isConnected() ? static_cast<int8_t>(WiFi.RSSI()) : 0;
}

void transportPublishStatus(uint16_t bpmValue, bool leadsOff, bool settled,
                            bool adcAlive) {
  g_bpm      = bpmValue;
  g_leadsOff = leadsOff;
  g_settled  = settled;
  g_adcAlive = adcAlive;
}

}  // namespace internal
}  // namespace ecg
