#include <math.h>

// Configuración del filtro (Ejemplo para 50 Hz con muestreo de 250 Hz)
// Estos coeficientes varían según si tu red eléctrica es de 50Hz o 60Hz.
// Ejemplo para 50 Hz:
#define COEFFICIENT_A 0.30901699f  // cos(2 * pi * 50 / 250)
#define R_FACTOR      0.95f        // Ancho de banda del filtro (0.9 a 0.99)

// Variables para almacenar el historial de la señal (búfer de retraso)
float x1 = 0.0f, x2 = 0.0f; // Entradas anteriores (con ruido)
float y1 = 0.0f, y2 = 0.0f; // Salidas anteriores (filtradas)

int aplicar_filtro_notch(int x0) {
    // Convertimos a flotante para el cálculo preciso
    float input = (float)x0;

    // Ecuación en diferencias del filtro Notch IIR
    float output = input - 2.0f * COEFFICIENT_A * x1 + x2 
                         + 2.0f * R_FACTOR * COEFFICIENT_A * y1 - (R_FACTOR * R_FACTOR) * y2;

    // Desplazamos el historial para la próxima muestra
    x2 = x1;
    x1 = input;
    y2 = y1;
    y1 = output;

    // Devolvemos el resultado casteado a entero
    return (int)output;
}