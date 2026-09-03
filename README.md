<div align="center">

<img src="Docs/Assets/banner.png" alt="ARES Banner" width="100%"/>

<br/>
<br/>

<p align="center">
<a href="https://github.com/impatrq/ARES"><img src="https://img.shields.io/static/v1?label=impatrq&message=ARES&color=b83939&logo=github&logoColor=white"/></a>
<a href="https://github.com/impatrq/ARES"><img src="https://img.shields.io/github/stars/impatrq/ARES?style=social"/></a>
<img src="https://img.shields.io/badge/Hardware-ESP32%20%2B%20AD8232-b83939"/>
<img src="https://img.shields.io/badge/Status-Prototipo-b83939"/>
</p>

<p align="center">
<a href="https://instagram.com/ares.proyecto/"><img src="https://img.shields.io/badge/Instagram-b83939?logo=instagram&logoColor=white"/></a>
<a href="https://tu-sitio-web.com/"><img src="https://img.shields.io/badge/Website-b83939?logo=googlechrome&logoColor=white"/></a>
</p>

</div>

## 📖 Documentación del Proyecto

Toda la documentación técnica y de seguimiento del sistema se encuentra centralizada en el directorio `/docs`.

* **Carpeta de Campo** `/docs/carpeta_de_campo/`: Contiene el registro iterativo del proyecto en formato `.pdf`. Documenta detalladamente el progreso semanal, las decisiones tomadas y el aporte técnico individual de cada integrante a lo largo del ciclo de desarrollo anual.
  
<div>&nbsp;</div>

## 🛠 Componentes Utilizados

* **Microcontrolador (ESP32-S3):** 
  * Ejecuta el firmware principal. Mantiene la transmisión de datos sin pérdida de paquetes bajo conexión Wi-Fi estable. Actualmente falta optimizar el modo Deep Sleep para mejorar la eficiencia energética.

* **Filtro Analógico / Sensor ECG (AD8232):** 
  * El acondicionamiento de la señal base es correcto, pero se requiere ajustar los filtros pasivos por hardware para reducir el ruido inducido por el movimiento del usuario.

* **Conversor Analógico-Digital (ADS1115):** 
  * Resuelve la falta de linealidad del ADC interno del ESP32. Aporta conversión de 16 bits, garantizando la resolución necesaria para interpretar la señal cardíaca del AD8232 sin distorsiones digitales.

* **Módulo de Carga (TP4056):** 
  * Gestiona la carga y protección de la batería de litio, asegurando la alimentación autónoma y segura del circuito completo.

> [!NOTE] 
> - Las imágenes y descripciones detalladas de cada elemento se encuentran en `/hardware/componentes/` 
> - Las hojas de datos de referencia se ubican en `/docs/datasheets/`

<div>&nbsp;</div>

## 🌟 Sobre el Proyecto

**ARES** (*Arrhythmia Real-time Evaluation System*) es un sistema IoT diseñado para el monitoreo electrocardiográfico continuo, que busca reemplazar cirugías invasivas. 

El proyecto resuelve la captura y transmisión de bioseñales en movimiento mediante la integración de hardware a medida, firmware de telemetría y una plataforma web, articulándose en los siguientes dominios:

## 🎯 Características Principales

* **Adquisición Analógica-Digital (Hardware):** Captura de ECG de un canal mediante un *front-end* analógico (AD8232) con filtrado activo. La digitalización se delega a un ADC de 16 bits (ADS1115), garantizando una resolución precisa y eliminando el ruido inherente al conversor interno del microcontrolador.
* **Procesamiento y Telemetría:** Un ESP32-S3 orquesta el muestreo estricto de los datos y ejecuta la transmisión continua e ininterrumpida de paquetes vía Wi-Fi, manteniendo una latencia optimizada hacia la nube.
* **Gestión Energética Autónoma:** El PCB cuenta con un circuito de carga y protección basado en el TP4056, diseñado para operar con baterías de litio y asegurar la autonomía del sistema durante las pruebas físicas.
* **Integración Wearable (Ergonomía):** Circuito miniaturizado (100% componentes SMD) embebido en un top deportivo de compresión. Utiliza electrodos textiles en el peto para mantener el contacto con la piel, eliminando adhesivos médicos y fricción mecánica.
* **Renderizado Web en Tiempo Real (Software):** Los paquetes telemétricos son recibidos por un *dashboard* remoto (desplegado en Vercel) que procesa y grafica la señal cardíaca a 60fps, ofreciendo una interfaz responsiva para la evaluación visual inmediata.

<div>&nbsp;</div>

## 🤝 Contacto

Para desarrollo, auditoría de hardware o consultas de inversión:

Mail - proyectoares26@gmail.com

Link del Proyecto: [https://github.com/impatrq/ARES](https://github.com/impatrq/ARES)