//  main.cpp  

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h> //libreria para hacer peticiones POST y GET
#include <SPI.h>
#include "ecg.h" //procesa el AD8232 y el ADS1115

//datos de conexion WiFi
static const char* kWifiSsid = "A16 de Tomas"; //red WIFI
static const char* kWifiPass = "to30gui21"; //contraseña de la red WIFI
static const char* kApiUrl  = "http:// 192.168.127.246:5000/api/canal"; //URL de la API

//funcion que envia los datos de latido a la API en C#
void enviarLatidoAPI(float valorECG, int bpm, int rrIntervalo, const char* estadoRitmo) {
  //verificamos que la placa siga conectada al WIFI antes de gastar recursos
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(kApiUrl); //apunto a la API de mi computadora
  http.addHeader("Content-Type", "application/json"); //aviso que mando texto formateado como JSON

  //serializamos a mano el objeto JSON que espera el Controller en C#
  String payload = "{";
  payload += "\"ValorECG\":" + String(valorECG, 2) + ",";
  payload += "\"Pulso\":" + String(bpm) + ",";
  payload += "\"IntervaloRR\":" + String(rrIntervalo) + ",";
  payload += "\"EstadoRitmo\":\"" + String(estadoRitmo) + "\"";
  payload += "}";

  //disparamos el POST a la red
  int httpCode = http.POST(payload);

  //si la PC responde con código 200 (OK), sabemos que SQL Server ya guardó la fila
  if (httpCode > 0) {
    Serial.printf("[API] Guardado en SQL -> %d BPM (%s) [HTTP %d]\n", bpm, estadoRitmo, httpCode);
  } else {
    Serial.printf("[API Error] Falló el POST: %s\n", http.errorToString(httpCode).c_str());
  }

  http.end(); //libero la memoria del cliente HTTP
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=== ECG ESP32-S3 ===");

  ecg::Config cfg;
  
  //pines del I2C para el ADS1115
  cfg.pinSda      = 8;
  cfg.pinScl      = 9;
  cfg.pinAdcReady = 4; //pin de interrupcion del ADS1115
  pinMode(cfg.pinAdcReady, INPUT_PULLUP);
  cfg.adsAddress  = 0x48; //direccion fisica I2C del ADS1115

  //pines digitales del AD8232 para saber si algun electrodo se despego del cuerpo
  cfg.pinLoPlus   = 5; //LO+ del AD8232
  cfg.pinLoMinus  = 6; //LO- del AD8232
  cfg.pinSdn      = 7; //SND del AD8232 (apaga el modulo si queremos ahorrar energia)

  //frecuencia de muestreo y modo de lectura del ADS1115 (250 muestras por segundo)
  cfg.sampleRateHz = 250;
  cfg.differential = false;

  //filtros digitales 
  cfg.mainsHz     = 50.0f;   //filtro notch para eliminar el ruido de la red electrica (50Hz en Argentina, 60Hz en USA)
  cfg.highPassHz  = 0.5f;    //filtro pasa-altos para eliminar la fluctuación causada por la respiración
  cfg.lowPassHz   = 40.0f;   //filtro pasa-bajos para eliminar el ruido por movimiento de músculos (EMG)
  cfg.enableNotch = true;
  cfg.enableBpm   = true;    //activo e ldetector de picos R (complejo QRS)

  //configuracion de la red WIFI y WebSocket para la grafica en tiempo real
  cfg.wifiSsid         = kWifiSsid;
  cfg.wifiPass         = kWifiPass;
  cfg.hostname         = "esp32-ecg";
  cfg.samplesPerPacket = 25; //agrupa 25 muestras antes de mandar el paquete de onda en vivo

  //inicio del Hardware, si un cable esta suelto del ADS1115, se detiene aca
  if (!ecg::begin(cfg)) {
    Serial.println("[main] el modulo ECG no arranco. Revisa el I2C.");
    return;
  }

  Serial.println("[main] ECG corriendo. Conectate a ws://<ip>/ecg");
}

void loop() {
  static uint32_t lastPrint = 0;
  static uint32_t lastApiSend = 0;

  //imprimo las estadisticas en el Monitor Serial cada 1 segundo
  if (millis() - lastPrint >= 1000) {
    lastPrint = millis();

    //consulto el estado actual que calcula el "ecg.h" (si hay electrodo desconectado, si el ADC esta vivo, si hay clientes WebSocket conectados, etc)
    const ecg::Status s = ecg::status();

    Serial.printf(
        "wifi=%d ip=%s cli=%d adc=%d leads=%s bpm=%3u "
        "muestras=%lu perdidas=%lu i2cerr=%lu tx=%lu drop=%lu rssi=%d\n",
        s.wifiConnected,
        WiFi.localIP().toString().c_str(),
        s.clientConnected,
        s.adcAlive,
        s.leadsOff ? "OFF" : "ok ",
        s.bpm,
        static_cast<unsigned long>(s.samplesAcquired),
        static_cast<unsigned long>(s.samplesMissed),
        static_cast<unsigned long>(s.i2cErrors),
        static_cast<unsigned long>(s.packetsSent),
        static_cast<unsigned long>(s.packetsDropped),
        s.rssi);

  //condicion de seguridad clinica:
  //solo enviamos a SQL si: -hay WIFI
                          //-los electrodos no estan despegados
                          //-el pulso es valido (>= 40 BPM)
  if (s.wifiConnected && !s.leadsOff && s.bpm >= 40 && (millis() - lastApiSend >= 2000)) {
      lastApiSend = millis();

      //clasificacion de las arritmias
      const char* estado = "NORMAL";
      if (s.bpm < 60) estado = "BRADICARDIA";
      else if (s.bpm > 100) estado = "TAQUICARDIA";
    
      //estimacion del intervalo entre latidos en milisegundos ($RR = \frac{60000}{BPM}$)
      int rr = 60000 / s.bpm;

      //envio a la API en C#
      enviarLatidoAPI(1.65f, s.bpm, rr, estado);
   }
  }

  delay(20); //pausa breve para no recalentar el procesador
}
