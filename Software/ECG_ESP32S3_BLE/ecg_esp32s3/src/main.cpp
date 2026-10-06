#include <Arduino.h>
#include <SPI.h>
#include "ecg.h" // Procesador del AD8232 y ADS1115

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== ARES: Monitor ECG ESP32-S3 con BLE ===");

  ecg::Config cfg;
  
  // Pines del I2C para el ADS1115
  cfg.pinSda      = 8;
  cfg.pinScl      = 9;
  cfg.pinAdcReady = 18; // Pin de interrupción del ADS1115
  pinMode(cfg.pinAdcReady, INPUT_PULLUP);
  cfg.adsAddress  = 0x48; // Dirección física I2C

  // Pines digitales del AD8232
  cfg.pinLoPlus   = 5;  // LO+ del AD8232
  cfg.pinLoMinus  = 6;  // LO- del AD8232
  cfg.pinSdn      = 4; // -1 si conectaste el SDN directamente a 3.3V físicos

  // Frecuencia de muestreo y configuración
  cfg.sampleRateHz = 250.0f; // Frecuencia de muestreo del ECG
  cfg.differential = false;

  // Filtros digitales
  cfg.mainsHz     = 50.0f;   // Filtro notch (50Hz)
  cfg.highPassHz  = 0.5f;    
  cfg.lowPassHz   = 40.0f;   
  cfg.enableNotch = true;
  cfg.enableBpm   = true;    // Activa el detector de picos R

  // Transporte BLE (sin WiFi)
  cfg.wifiSsid         = "BLE_MODE"; 
  cfg.wifiPass         = nullptr;
  cfg.samplesPerPacket = 5; 

  // Inicialización del hardware ECG
  if (!ecg::begin(cfg)) {
    Serial.println("[main] El módulo ECG no arrancó. Revisá el I2C y las conexiones.");
    return;
  }

  Serial.println("[main] Sistema ECG inicializado. Esperando conexión BLE de la app...");
}

void loop() {
  static uint32_t lastPrint = 0;

  if (millis() - lastPrint >= 1000) {
    lastPrint = millis();
    const ecg::Status s = ecg::status();

    Serial.printf(
        "leads=%s | bpm=%3u | muestras=%lu | i2cerr=%lu | tx=%lu\n",
        s.leadsOff ? "DESPEGADOS" : "OK        ",
        s.bpm,
        static_cast<unsigned long>(s.samplesAcquired),
        static_cast<unsigned long>(s.samplesMissed),
        static_cast<unsigned long>(s.i2cErrors),
        static_cast<unsigned long>(s.packetsSent)
    );
  }

  delay(20);
}