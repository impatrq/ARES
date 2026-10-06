#include <Arduino.h>
#include <Wire.h>

void setup() {
  Serial.begin(115200);
  delay(1500);
  Serial.println("\n--- ESCANEANDO BUS I2C ---");
  Wire.begin(8, 9); // SDA=8, SCL=9
}

void loop() {
  byte error, address;
  int encontrados = 0;

  for (address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    error = Wire.endTransmission();

    if (error == 0) {
      Serial.printf("¡ADS1115 encontrado en la dirección: 0x%02X!\n", address);
      encontrados++;
    }
  }

  if (encontrados == 0) {
    Serial.println("No se detecta nada. Falla de pines/soldadura/alimentación.");
  }
  Serial.println("----------------------------------------");
  delay(2000);
}