/**
 * ARES Cardiac Monitor — firmware ESP32-S3
 * ------------------------------------------------------------------------
 * Lee la señal de ECG del AD8232 a través del ADS1115 (I2C), arma ventanas
 * de EI_CLASSIFIER_RAW_SAMPLE_COUNT muestras a EI_CLASSIFIER_FREQUENCY Hz,
 * corre el clasificador de Edge Impulse ("ARES_cardiac_monitor") y
 * transmite el resultado ("estable" / "anomalia" / "sin_contacto") por
 * BLE (NimBLE) para que la app del celular lo reciba.
 *
 * *** IMPORTANTE — LEER ANTES DE USAR ***
 * El modelo se entrenó con un dataset PÚBLICO de ECG (no con este sensor).
 * Por eso este firmware incluye un MODO DE CALIBRACIÓN (ver CALIBRATION_MODE
 * más abajo) para ajustar ganancia/offset y acercar la señal real del
 * AD8232+ADS1115 a la escala que el modelo espera. Es un ajuste
 * aproximado (amplitud + línea de base), no una garantía de equivalencia
 * total: la forma de onda también depende del filtrado analógico propio
 * del AD8232, que puede diferir del origen del dataset. Para un sistema
 * confiable a futuro, lo ideal es reentrenar / hacer fine-tuning con datos
 * grabados con este mismo hardware.
 * Este dispositivo NO es un instrumento médico certificado.
 *
 * Librerías necesarias (agregar en platformio.ini, ver archivo adjunto):
 *   - adafruit/Adafruit ADS1X15
 *   - h2zero/NimBLE-Arduino (pineada a 1.4.x — la API de callbacks de BLE
 *     cambió en versiones 2.x)
 */

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_ADS1X15.h>
#include <NimBLEDevice.h>
#include <esp_timer.h>
#include <string.h>

#include "edge-impulse-sdk/classifier/ei_run_classifier.h"

// ---------------------------------------------------------------------------
// CONFIGURACIÓN DE HARDWARE (según lo confirmado para esta placa/cableado)
// ---------------------------------------------------------------------------
#define PIN_I2C_SDA        8
#define PIN_I2C_SCL        9
#define PIN_LO_PLUS        5     // LO+ del AD8232 (HIGH = electrodo despegado)
#define PIN_LO_MINUS       6     // LO- del AD8232 (HIGH = electrodo despegado)
#define ADS1115_ADDR       0x48  // dirección I2C por defecto (ADDR -> GND)
#define ADS1115_CHANNEL    0     // AD8232 OUTPUT -> entrada A0 del ADS1115

// ---------------------------------------------------------------------------
// SIMULACIÓN — para probar el firmware SIN el ADS1115/AD8232 conectados
// ---------------------------------------------------------------------------
// Poner en 1 para saltear por completo la lectura del ADS1115: cada pocos
// segundos corre el clasificador sobre un buffer de prueba embebido
// (ei_simulation_buffer, más abajo) y manda el resultado por BLE. Sirve
// para validar, con solo la placa ESP32-S3 (sin protoboard ni electrodos),
// que el modelo carga y corre bien y que la app puede conectarse y recibir
// notificaciones BLE. NO usar junto con CALIBRATION_MODE a la vez.
#define SIMULATION_MODE    1

// Cada cuántos milisegundos corre una inferencia de prueba en modo simulación
#define SIMULATION_INTERVAL_MS   5000

// ---------------------------------------------------------------------------
// CALIBRACIÓN — ver instrucciones de uso en la respuesta del chat
// ---------------------------------------------------------------------------
// Poner en 1 para SOLO imprimir la señal condicionada por Serial (una
// muestra por línea, ideal para el Serial Plotter) y NO correr el
// clasificador. Sirve para comparar visualmente contra los gráficos de
// "Raw Data" de Edge Impulse Studio y ajustar las constantes de abajo.
#define CALIBRATION_MODE   0

// Filtro pasa-altos de un polo (DC-block) que remueve la línea de base
// (~1.65V) que introduce el AD8232, dejando sólo la parte "AC" de la señal
// cardíaca. Más cerca de 1.0 = corte más bajo (deja pasar más línea base).
#define DC_BLOCK_ALPHA     0.995f

// AJUSTAR EN CALIBRACIÓN: multiplicador y offset para acercar la amplitud
// y la línea de base de la señal real a la escala del dataset de
// entrenamiento (aprox. entre -2.5 y +2.0, línea de base cerca de -1.0,
// según lo observado en Edge Impulse Studio).
#define CALIBRATION_GAIN   1.0f
#define CALIBRATION_OFFSET 0.0f

// Umbral de confianza del proyecto en Edge Impulse Studio
#define CONFIDENCE_THRESHOLD 0.6f

// ---------------------------------------------------------------------------
// BLE — compartir estos UUIDs con el equipo de la app móvil
// ---------------------------------------------------------------------------
#define BLE_DEVICE_NAME        "ARES-CardiacMonitor"
#define SERVICE_UUID           "6b6f0001-8c37-4d5a-9b1a-1e2c9f6d1a10"
#define CHARACTERISTIC_UUID    "6b6f0002-8c37-4d5a-9b1a-1e2c9f6d1a10"

Adafruit_ADS1115 ads;
NimBLECharacteristic* pCharacteristic = nullptr;
NimBLEServer* pServer = nullptr;
volatile bool bleClientConnected = false;

// ---------------------------------------------------------------------------
// Buffer de la ventana de inferencia
// ---------------------------------------------------------------------------
static float ei_buffer[EI_CLASSIFIER_RAW_SAMPLE_COUNT];
static size_t ei_buffer_pos = 0;

volatile bool sampleFlagReady = false;
esp_timer_handle_t samplingTimer;

static float dcBlockPrevRaw = 0.0f;
static float dcBlockPrevFiltered = 0.0f;
static bool dcBlockInitialized = false;

#if SIMULATION_MODE
// Buffer de prueba: por ahora queda en cero (solo prueba que el pipeline
// corre sin colgarse y que BLE notifica). Para una prueba con significado
// real, reemplazar por los 600 valores de "ecg" de una muestra exportada
// desde Edge Impulse Studio: Data acquisition -> abrir una muestra -> menú
// "..." -> "Download raw data" / "Download JSON", y pegar acá los valores.
static const float ei_simulation_buffer[EI_CLASSIFIER_RAW_SAMPLE_COUNT] = {
    // TODO: pegar acá los 600 valores reales de una muestra de Edge Impulse
};
#endif

// ---------------------------------------------------------------------------
// Timer de hardware -> dispara cada EI_CLASSIFIER_INTERVAL_MS (5ms = 200Hz,
// la misma frecuencia con la que se entrenó el modelo). Solo prende una
// bandera: la lectura I2C real se hace en loop(), nunca dentro del timer.
// ---------------------------------------------------------------------------
void onSamplingTimer(void* arg) {
    sampleFlagReady = true;
}

// ---------------------------------------------------------------------------
// Callbacks de conexión BLE
// ---------------------------------------------------------------------------
class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* server) override {
        bleClientConnected = true;
        Serial.println("[BLE] App conectada.");
    }
    void onDisconnect(NimBLEServer* server) override {
        bleClientConnected = false;
        Serial.println("[BLE] App desconectada, reanudando advertising...");
        NimBLEDevice::startAdvertising();
    }
};

void setupBLE() {
    NimBLEDevice::init(BLE_DEVICE_NAME);
    pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    NimBLEService* pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );
    pCharacteristic->setValue("inicializando");
    pService->start();

    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->start();

    Serial.println("[BLE] Advertising iniciado.");
}

void sendResultBLE(const char* status) {
    if (pCharacteristic == nullptr) return;
    pCharacteristic->setValue(status);
    if (bleClientConnected) {
        pCharacteristic->notify();
    }
}

// ---------------------------------------------------------------------------
// Callback que Edge Impulse usa para leer el buffer de la ventana
// ---------------------------------------------------------------------------
int ei_get_data(size_t offset, size_t length, float* out_ptr) {
    memcpy(out_ptr, ei_buffer + offset, length * sizeof(float));
    return 0;
}

void runInference() {
    signal_t signal;
    signal.total_length = EI_CLASSIFIER_RAW_SAMPLE_COUNT;
    signal.get_data = &ei_get_data;

    ei_impulse_result_t result = { 0 };
    EI_IMPULSE_ERROR err = run_classifier(&signal, &result, false);

    if (err != EI_IMPULSE_OK) {
        Serial.printf("[EI] Error al correr el clasificador (%d)\n", err);
        return;
    }

    float bestValue = 0.0f;
    const char* bestLabel = "desconocido";
    for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT; ix++) {
        Serial.printf("  %s: %.3f\n", result.classification[ix].label, result.classification[ix].value);
        if (result.classification[ix].value > bestValue) {
            bestValue = result.classification[ix].value;
            bestLabel = result.classification[ix].label;
        }
    }

    const char* status;
    if (bestValue < CONFIDENCE_THRESHOLD) {
        status = "inconcluso"; // ninguna clase superó el umbral del proyecto
    } else if (strcmp(bestLabel, "anomalia") == 0) {
        status = "anomalia";
    } else {
        status = "estable";
    }

    Serial.printf("[EI] Resultado: %s (confianza %.2f)\n", status, bestValue);
    sendResultBLE(status);
}

// ---------------------------------------------------------------------------
// Lee una muestra del ADS1115, la convierte a voltios y aplica el filtro
// DC-block + la calibración de ganancia/offset
// ---------------------------------------------------------------------------
float readConditionedSample() {
    int16_t raw = ads.readADC_SingleEnded(ADS1115_CHANNEL);
    float volts = ads.computeVolts(raw);

    if (!dcBlockInitialized) {
        dcBlockPrevRaw = volts;
        dcBlockPrevFiltered = 0.0f;
        dcBlockInitialized = true;
    }

    float filtered = DC_BLOCK_ALPHA * (dcBlockPrevFiltered + volts - dcBlockPrevRaw);
    dcBlockPrevRaw = volts;
    dcBlockPrevFiltered = filtered;

    return (filtered * CALIBRATION_GAIN) + CALIBRATION_OFFSET;
}

void setup() {
    Serial.begin(115200);
    delay(300);
    Serial.println("\n=== ARES Cardiac Monitor ===");

    pinMode(PIN_LO_PLUS, INPUT);
    pinMode(PIN_LO_MINUS, INPUT);

#if !SIMULATION_MODE
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    if (!ads.begin(ADS1115_ADDR)) {
        Serial.println("[ERROR] No se detecto el ADS1115. Revisa el cableado I2C (SDA=8, SCL=9).");
        while (true) { delay(1000); }
    }
    ads.setGain(GAIN_TWOTHIRDS);           // +/-6.144V, default de la libreria Adafruit
    ads.setDataRate(RATE_ADS1115_860SPS);  // necesario para poder muestrear a 200Hz sin atrasarse
#else
    Serial.println("*** SIMULATION_MODE ACTIVO: no se usa ADS1115/AD8232 ***");
#endif

    setupBLE();

#if !SIMULATION_MODE
    const esp_timer_create_args_t timerArgs = {
        .callback = &onSamplingTimer,
        .arg = nullptr,
        .dispatch_method = ESP_TIMER_TASK,
        .name = "ecg_sampler"
    };
    esp_timer_create(&timerArgs, &samplingTimer);
    esp_timer_start_periodic(samplingTimer, EI_CLASSIFIER_INTERVAL_MS * 1000ULL); // en microsegundos
#endif

    Serial.printf("Modelo: %d muestras a %dHz (ventana de %.1fs) | Umbral: %.2f\n",
                  EI_CLASSIFIER_RAW_SAMPLE_COUNT, EI_CLASSIFIER_FREQUENCY,
                  (float)EI_CLASSIFIER_RAW_SAMPLE_COUNT / EI_CLASSIFIER_FREQUENCY,
                  CONFIDENCE_THRESHOLD);

#if CALIBRATION_MODE
    Serial.println("*** MODO CALIBRACION ACTIVO: no se corre el clasificador ***");
#endif
}

#if SIMULATION_MODE
void loopSimulation() {
    static uint32_t lastRun = 0;
    if (millis() - lastRun < SIMULATION_INTERVAL_MS) {
        return;
    }
    lastRun = millis();

    memcpy(ei_buffer, ei_simulation_buffer, sizeof(ei_buffer));
    Serial.println("[SIM] Corriendo clasificador sobre el buffer de prueba...");
    runInference();
}
#endif

void loop() {
#if SIMULATION_MODE
    loopSimulation();
    return;
#endif

    if (!sampleFlagReady) {
        return;
    }
    sampleFlagReady = false;

    bool leadsOff = (digitalRead(PIN_LO_PLUS) == HIGH) || (digitalRead(PIN_LO_MINUS) == HIGH);
    if (leadsOff) {
        static uint32_t lastWarn = 0;
        if (millis() - lastWarn > 2000) {
            Serial.println("[AVISO] Electrodos desconectados (LO+/LO-)");
            sendResultBLE("sin_contacto");
            lastWarn = millis();
        }
        ei_buffer_pos = 0; // no mezclar la ventana con ruido de desconexion
        dcBlockInitialized = false;
        return;
    }

    float sample = readConditionedSample();

#if CALIBRATION_MODE
    Serial.println(sample, 4); // una muestra por linea -> Serial Plotter
#else
    ei_buffer[ei_buffer_pos++] = sample;
    if (ei_buffer_pos >= EI_CLASSIFIER_RAW_SAMPLE_COUNT) {
        runInference();
        ei_buffer_pos = 0;
    }
#endif
}