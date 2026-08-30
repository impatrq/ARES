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

**ARES** (*Arrhythmia Real-time Evaluation System*) es un sistema IoT *wearable* de grado experimental diseñado para el monitoreo electrocardiográfico continuo y no invasivo. 

El proyecto resuelve la captura y transmisión de bioseñales en movimiento mediante la integración de hardware a medida, firmware de telemetría y una plataforma web, articulándose en los siguientes dominios:

* **Hardware y Acondicionamiento (Electrónica):** Circuito impreso (PCB) propietario con componentes de montaje superficial (SMD). Utiliza un *front-end* analógico AD8232 para la amplificación y filtrado activo de la señal cardíaca, digitalizada con precisión a través de un ADC de 16 bits (ADS1115).
* **Integración Wearable (Ergonomía):** El sistema electrónico está embebido en un top deportivo de compresión, empleando electrodos en el peto para garantizar el contacto continuo con la piel sin necesidad de adhesivos médicos tradicionales.
* **Procesamiento y Telemetría (Telecomunicaciones):** Un microcontrolador ESP32-S3 orquesta el muestreo riguroso del ADC y transmite los paquetes de datos por Wi-Fi de forma ininterrumpida y con baja latencia.
* **Presentación de Datos (Informática):** Los datos son recibidos y renderizados a 60fps en un *dashboard* web responsivo (desplegado en Vercel), permitiendo la evaluación visual de la actividad eléctrica del corazón en tiempo real.
<div align="center"> 
  <img src="Docs/Assets/pagina-web.png" alt="ARES Página Web" width="Auto" height="Auto" />
</div>

## 🎯 Características Principales

* **Adquisición de Señal de Alta Resolución:** Captura de ECG de derivación única (un canal) mediante el *front-end* analógico AD8232. La digitalización se delega a un ADC dedicado de 16 bits (ADS1115), garantizando una lectura fiel sin el ruido inherente al conversor interno del microcontrolador.
* **Telemetría de Baja Latencia:** Transmisión continua de paquetes de datos utilizando la pila Wi-Fi del ESP32-S3. Arquitectura optimizada para sostener el flujo de telemetría en tiempo real hacia la nube.
* **Gestión de Energía Autónoma:** Circuito de carga y protección integrado (basado en el TP4056) para operar con baterías de litio, asegurando ciclos de carga seguros y autonomía durante la actividad física.
* **Factor de Forma Wearable:** PCB miniaturizado con diseño enteramente SMD (Surface-Mount Device). Todo el hardware se aloja y oculta en la estructura de un top deportivo de compresión, utilizando electrodos textiles para evitar la fricción y los adhesivos médicos.
* **Visualización Web de Alto Rendimiento:** *Dashboard* remoto desplegado en la nube que procesa y renderiza la señal cardíaca a 60fps. Interfaz responsiva diseñada para el monitoreo visual fluido del usuario durante las pruebas de campo.

<div>&nbsp;</div>

## 🤝 Contacto

Para desarrollo, auditoría de hardware o consultas de inversión:

Mail - proyectoares26@gmail.com

Link del Proyecto: [https://github.com/impatrq/ARES](https://github.com/impatrq/ARES)