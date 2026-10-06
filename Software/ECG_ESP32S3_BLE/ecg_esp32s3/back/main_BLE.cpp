#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_ADS1X15.h>
#include <NimBLEDevice.h>
#include <edge-impulse-sdk/classifier/ei_run_classifier.h>

// ==========================================
// ASIGNACIÓN DE PINES FÍSICOS
// ==========================================
#define PIN_SDA        17
#define PIN_SCL        18
#define PIN_ADC_READY  4
#define PIN_LO_PLUS    1   // LO+ del AD8232
#define PIN_LO_MINUS   2   // LO- del AD8232
//#define PIN_SDN        3   // SDN del AD8232

// ==========================================
// CONFIGURACIÓN BLE
// ==========================================
#define SERVICE_UUID        "6b6f0001-8c37-4d5a-9b1a-1e2c9f6d1a10"
#define CHAR_STATUS_UUID    "6b6f0002-8c37-4d5a-9b1a-1e2c9f6d1a10"
#define CHAR_ECG_STREAM_UUID "6b6f0003-8c37-4d5a-9b1a-1e2c9f6d1a10"

static NimBLEServer* pServer = nullptr;
static NimBLECharacteristic* pCharStatus = nullptr;
static NimBLECharacteristic* pCharStream = nullptr;
static bool deviceConnected = false;

// ==========================================
// MUESTREO E INFERENCIA
// ==========================================
#define SAMPLING_FREQ_HZ       100 
#define SAMPLING_INTERVAL_US   (1000000 / SAMPLING_FREQ_HZ)

Adafruit_ADS1115 ads;

static float features[EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE];
static size_t feature_idx = 0;

static const uint8_t BATCH_SIZE = 5;
static float stream_batch[BATCH_SIZE];
static uint8_t stream_idx = 0;

volatile float lastVoltage = 0.0f;
volatile int16_t lastAdcRaw = 0;
volatile bool leadsOffState = false;
static String lastDiagnosis = "iniciando";
static float lastConfidence = 0.0f;
static uint32_t totalSamples = 0;

// BPM y Histéresis
static uint32_t lastPeakTime = 0;
static float currentBPM = 0.0f;
const float R_PEAK_THRESHOLD = 1.95f;       
const uint32_t MIN_PEAK_INTERVAL_MS = 300;    
static bool esperandoBajada = false;
const float R_PEAK_RESET_THRESHOLD = 1.75f; // Umbral de reinicio de histéresis[cite: 8]

TaskHandle_t SamplingTaskHandle = NULL;
SemaphoreHandle_t i2cMutex = NULL;

int raw_feature_get_data(size_t offset, size_t length, float *out_ptr) {
    memcpy(out_ptr, features + offset, length * sizeof(float));
    return 0;
}

// ==========================================
// CALLBACKS BLE
// ==========================================
class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) override {
        deviceConnected = true;
        Serial.println("\n>>> [BLE] App conectada exitosamente. <<<");
    }

    void onDisconnect(NimBLEServer* pServer) override {
        deviceConnected = false;
        Serial.println("\n>>> [BLE] App desconectada. Reiniciando publicidad... <<<");
        NimBLEDevice::startAdvertising();
    }
};

void initBLE() {
    NimBLEDevice::init("ARES-CardiacMonitor");
    NimBLEDevice::setPower(ESP_PWR_LVL_P9);

    pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    NimBLEService* pService = pServer->createService(SERVICE_UUID);

    pCharStatus = pService->createCharacteristic(
        CHAR_STATUS_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );
    pCharStatus->setValue("buscando");

    pCharStream = pService->createCharacteristic(
        CHAR_ECG_STREAM_UUID,
        NIMBLE_PROPERTY::NOTIFY
    );

    pService->start();

    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->start();
    Serial.println("[BLE] Servidor y Advertising listos.");
}

// ==========================================
// TAREA DE ADQUISICIÓN EN TIEMPO REAL (CORE 1)
// ==========================================
void ecgSamplingTask(void *pvParameters) {
    TickType_t xLastWakeTime;
    const TickType_t xFrequency = pdMS_TO_TICKS(10); // 10ms = 100Hz exactos
    xLastWakeTime = xTaskGetTickCount();

    while (1) {
        int loPlusVal = digitalRead(PIN_LO_PLUS);
        int loMinusVal = digitalRead(PIN_LO_MINUS);
        leadsOffState = (loPlusVal == HIGH || loMinusVal == HIGH);

        if (!leadsOffState) {
            if (xSemaphoreTake(i2cMutex, (TickType_t)5) == pdTRUE) {
                lastAdcRaw = ads.readADC_SingleEnded(0);
                lastVoltage = ads.computeVolts(lastAdcRaw);
                xSemaphoreGive(i2cMutex);
            }
            totalSamples++;

            // Detección de Pico R con Histéresis
            if (!esperandoBajada) {
                if (lastVoltage > R_PEAK_THRESHOLD && (millis() - lastPeakTime > MIN_PEAK_INTERVAL_MS)) {
                    uint32_t rrInterval = millis() - lastPeakTime;
                    lastPeakTime = millis();
                    esperandoBajada = true; //[cite: 8]

                    if (rrInterval >= 300 && rrInterval <= 1500) {
                        float instantBPM = 60000.0f / (float)rrInterval;
                        currentBPM = (currentBPM == 0.0f) ? instantBPM : (currentBPM * 0.7f) + (instantBPM * 0.3f);
                    }
                }
            } else {
                if (lastVoltage < R_PEAK_RESET_THRESHOLD) {
                    esperandoBajada = false; //[cite: 8]
                }
            }

            // Almacenamiento para Edge Impulse y streaming
            features[feature_idx++] = lastVoltage;
            if (feature_idx >= EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE) {
                feature_idx = 0; 
            }

            stream_batch[stream_idx++] = lastVoltage;
            if (stream_idx >= BATCH_SIZE) {
                stream_idx = 0;
            }
        }

        vTaskDelayUntil(&xLastWakeTime, xFrequency);
    }
}

// ==========================================
// SETUP PRINCIPAL
// ==========================================
void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("\n=== ARES: Monitor Cardíaco BLE Multitarea ===");

    pinMode(PIN_LO_PLUS, INPUT_PULLDOWN);
    pinMode(PIN_LO_MINUS, INPUT_PULLDOWN);
    //pinMode(PIN_SDN, OUTPUT);
    //digitalWrite(PIN_SDN, HIGH); 

    Wire.begin(PIN_SDA, PIN_SCL);
    Wire.setClock(100000); 
    Wire.setTimeOut(30);

    if (!ads.begin(0x48)) {
        Serial.println("[ERROR] No se detectó el ADS1115 en 0x48.");
    } else {
        Serial.println("[ADC] ADS1115 inicializado correctamente (0x48).");
        ads.setGain(GAIN_ONE);
    }

    i2cMutex = xSemaphoreCreateMutex();
    initBLE();

    xTaskCreatePinnedToCore(
        ecgSamplingTask,
        "ECG_Sampling_Task",
        4096,
        NULL,
        3,
        &SamplingTaskHandle,
        1
    );
}

// ==========================================
// BUCLE PRINCIPAL (CORE 0: BLE + IA)
// ==========================================
void loop() {
    static uint32_t lastTelemetriaPrint = 0;

    if (deviceConnected && !leadsOffState) {
        String batchStr = "";
        for (int i = 0; i < BATCH_SIZE; i++) {
            batchStr += String(stream_batch[i], 3);
            if (i < BATCH_SIZE - 1) batchStr += ",";
        }
        pCharStream->setValue(batchStr.c_str());
        pCharStream->notify();
    }

    if (feature_idx == 0) { 
        signal_t signal;
        signal.total_length = EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE;
        signal.get_data = &raw_feature_get_data;

        ei_impulse_result_t result = { 0 };
        EI_IMPULSE_ERROR ei_err = run_classifier(&signal, &result, false);

        if (ei_err == EI_IMPULSE_OK) {
            float maxScore = 0.0f;
            const char* detectedState = "estable";

            for (size_t ix = 0; ix < EI_CLASSIFIER_LABEL_COUNT; ix++) {
                if (result.classification[ix].value > maxScore) {
                    maxScore = result.classification[ix].value;
                    detectedState = result.classification[ix].label;
                }
            }
            lastDiagnosis = detectedState;
            lastConfidence = maxScore;

            if (deviceConnected) {
                pCharStatus->setValue(detectedState);
                pCharStatus->notify();
            }
        }
    }

    if (millis() - lastTelemetriaPrint >= 1000) {
        lastTelemetriaPrint = millis();
        Serial.printf(
            "ble=%s | leads=%s | raw=%6d | volt=%.3fV | bpm=%3.0f | ia=%s (%.2f)\n",
            deviceConnected ? "CONECTADO" : "buscando ",
            leadsOffState ? "DESPEGADOS" : "OK       ",
            (int)lastAdcRaw,
            (float)lastVoltage,
            currentBPM,
            lastDiagnosis.c_str(),
            lastConfidence
        );
    }

    vTaskDelay(pdMS_TO_TICKS(20));
}