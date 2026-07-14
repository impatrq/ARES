#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_adc/adc_oneshot.h" 

// CONFIGURACION DE PINES
#define LO_PLUS    GPIO_NUM_18
#define LO_MINUS   GPIO_NUM_19
#define ECG_CHANNEL ADC_CHANNEL_6 // GPIO34 en ADC1

void app_main(void)
{
    // CONFIGURACIÓN DE ADC 
    adc_oneshot_unit_handle_t adc1_handle;
    // INICIALIZO ADC: LO CONFIGURO PARA ADC1 Y EN MODO NORMAL (NO ULP)
    adc_oneshot_unit_init_cfg_t init_config1 = {
        .unit_id = ADC_UNIT_1,
        .ulp_mode = ADC_ULP_MODE_DISABLE,
    };
    // CREACION DE LA UNIDAD ADC1
    adc_oneshot_new_unit(&init_config1, &adc1_handle);
    // CONFIGURO EL ADC1 CON ATENUACION DE 12db Y RESOLUCION DE 12 BITS
    adc_oneshot_chan_cfg_t config = {
        .atten = ADC_ATTEN_DB_12,
        .bitwidth = ADC_BITWIDTH_12,
    };
    adc_oneshot_config_channel(adc1_handle, ECG_CHANNEL, &config);

    // CONFIGURO GPIO 
    gpio_reset_pin(LO_PLUS);
    gpio_reset_pin(LO_MINUS);
    gpio_set_direction(LO_PLUS, GPIO_MODE_INPUT);
    gpio_set_direction(LO_MINUS, GPIO_MODE_INPUT);

    // ACTIVO RESISTENCIA PULLDOWN INTERNAS PARA EVITAR LECTURAS FALSAS AL AIRE
    gpio_set_pull_mode(LO_PLUS, GPIO_PULLDOWN_ONLY);
    gpio_set_pull_mode(LO_MINUS, GPIO_PULLDOWN_ONLY);

    while (true)
    {
        // LEO EL ESTADO DE LOS ELECTRODOS (0 - 1)
        int plus = gpio_get_level(LO_PLUS);
        int minus = gpio_get_level(LO_MINUS);

        if (plus == 1 || minus == 1) 
        {
            // ELECTRODOS DESCONECTADOS: MANDO 0
            printf("0\n");
        } 
        else 
        {
            // ELECTRODOS BIEN PUESTOS: LEO EL ECG CON LA NUEVA FUNCIÓN, ADC GENERA UN VALOR ENTRE 0 Y 4095 (12 BITS)
            // Y LO GUARDO EN LA VARIABLE ecg_value
            int ecg_value = 0;
            adc_oneshot_read(adc1_handle, ECG_CHANNEL, &ecg_value);
            printf(">ecg:%d\n", ecg_value);
        }

        // DELAY DE 4ms (MUESTREO PERFECTO A 250Hz)
        vTaskDelay(pdMS_TO_TICKS(4));
    }
}