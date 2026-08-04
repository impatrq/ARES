#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_adc/adc_oneshot.h" 
#include <math.h>

// CONFIGURACION DE PINES
#define LO_PLUS    GPIO_NUM_18
#define LO_MINUS   GPIO_NUM_19
#define ECG_CHANNEL ADC_CHANNEL_6 // GPIO34 en ADC1

//CONSTANTES DEL FILTRO NOTCH PARA 50Hz
#define COEFFICIENT_A 0.30901699f  // cos(2 * pi * 50 / 250)
#define R_FACTOR      0.95f        // Ancho de banda del filtro (0.9 a 0.99)

//CONFIGURACIÓN DEL BÚFER PARA LA API (1 segundo de datos a 250Hz)
#define BUFFER_SIZE 250
int ecg_buffer[BUFFER_SIZE];
int buffer_index = 0;

//HISTORIAL DEL FILTRO NOTCH
float x1 = 0.0f, x2 = 0.0f;
float y1 = 0.0f, y2 = 0.0f;

//FUNCION DEL FILTRO NOTCH
int aplicar_filtro_notch(float x0) {
    // CONVERTIMOS A FLOTANTE PARA CALCULO PRECISO
    float input = (float)x0;

    // ECUACION EN DIFERENCIAS DEL FILTRO NOTCH IIR DE 2DO ORDEN
    float output = input - 2.0f * COEFFICIENT_A * x1 + x2 
                         + 2.0f * R_FACTOR * COEFFICIENT_A * y1 - (R_FACTOR * R_FACTOR) * y2;

    // DESPLAZAMOS EL HISTORIAL PARA LA PROXIMA MUESTRA
    x2 = x1;
    x1 = input;
    y2 = y1;
    y1 = output;

    // DEVOLVEMOS EL RESULTADO A ENTERO
    return (int)output;
}
// FUNCIÓN AUXILIAR PARA SIMULAR EL ENVÍO A LA API
void procesar_lote_completado() {
    printf("\n--- [LOTE LISTO] 250 Muestras procesadas para enviar a la API ---\n");
    printf("Muestra [0]: %d | Muestra [249]: %d\n\n", ecg_buffer[0], ecg_buffer[249]);
}

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
            ecg_buffer[buffer_index] = 0;
            printf("0\n");
        } 
        else 
        {
            // ELECTRODOS BIEN PUESTOS: LEO EL ECG CON LA NUEVA FUNCIÓN, ADC GENERA UN VALOR ENTRE 0 Y 4095 (12 BITS)
            // Y LO GUARDO EN LA VARIABLE ecg_value
            int ecg_value = 0;
            adc_oneshot_read(adc1_handle, ECG_CHANNEL, &ecg_value);

            // APLICO EL FILTRO NOTCH DE 50Hz
            int ecg_filtrado = aplicar_filtro_notch(ecg_value);

            // GUARDO EL DATO FILTRADO EN EL BUFER PARA ENVIARLO A LA API
            ecg_buffer[buffer_index] = ecg_filtrado;
        }
        
        //AVANZAMOS EL INDICE DEL BUFFER, SI LLEGA A 250, LO REINICIAMOS Y SIMULAMOS EL ENVÍO A LA API
        buffer_index++;
        
        //SI LLENAMOS EL BUFFER (250 MUESTRAS), SIMULAMOS EL ENVÍO A LA API Y REINICIAMOS EL INDICE
        if (buffer_index >= BUFFER_SIZE)
        {
            procesar_lote_completado();
            buffer_index = 0; // REINICIAMOS PARA EL PROXIMO SEGUNDO
        }

        // DELAY DE 4ms (MUESTREO A 250Hz)
        vTaskDelay(pdMS_TO_TICKS(4));
    }
}