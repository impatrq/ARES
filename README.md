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

* **Carpeta de Campo (`/docs/carpeta_de_campo/`):** Contiene el registro iterativo del proyecto en formato `.pdf`. Documenta detalladamente el progreso semanal, las decisiones tomadas y el aporte técnico individual de cada integrante a lo largo del ciclo de desarrollo anual.
  
<div>&nbsp;</div>

<h2>🛠 Componentes </h2>

<table>
  <thead>
    <tr>
      <th>Componente</th>
      <th>Estado</th>
      <th>Fiabilidad</th>
      <th>Notas</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Firmware ESP32</strong></td>
      <td>Estable</td>
      <td>Alta</td>
      <td>Transmisión de datos sin pérdida de paquetes bajo conexión Wi-Fi estable. Falta optimizar el modo Deep Sleep.</td>
    </tr>
    <tr>
      <td><strong>Filtro Analógico (AD8232)</strong></td>
      <td>En pruebas</td>
      <td>Media</td>
      <td>El acondicionamiento de la señal es correcto, pero se requiere ajustar los filtros pasivos para reducir el ruido por movimiento del usuario.</td>
    </tr>
    <tr>
      <td><strong>Electrodos en Peto</strong></td>
      <td>Prototipo</td>
      <td>Baja</td>
      <td>Los electrodos textiles integrados en la prenda negra necesitan mejor conductividad con la piel seca.</td>
    </tr>
    <tr>
      <td><strong>Dashboard Web (Vercel)</strong></td>
      <td>Estable</td>
      <td>Alta</td>
      <td>Renderizado de gráficas a 60fps funcional. Latencia inferior a 50ms.</td>
    </tr>
  </tbody>
</table>

> [!WARNING]
> - **Descargo de Responsabilidad Médica:** ARES es un proyecto de investigación y desarrollo. Actualmente **no es un dispositivo médico certificado**. No debe utilizarse para diagnósticos clínicos, soporte vital o toma de decisiones médicas sin la supervisión de un profesional de la salud.
> - **Sensibilidad al Ruido:** Debido a la naturaleza del monitoreo en movimiento, la señal del ECG puede presentar artefactos si la prenda no ejerce la compresión adecuada sobre el torso.

<div>&nbsp;</div>

<!-- About the Project -->
## 🌟 Sobre el Proyecto

ARES (Arrhythmia Real-time Evaluation System) es un sistema portátil de monitoreo electrocardiográfico continuo. Consiste en un circuito impreso (PCB) con componentes SMD, basado en un microcontrolador ESP32 y un módulo analógico AD8232, completamente integrado en un top deportivo. 

El objetivo es capturar, filtrar y transmitir la actividad eléctrica del corazón en tiempo real hacia una plataforma web, permitiendo la detección temprana de anomalías cardíacas.

<div align="center"> 
  <img src="Docs/Assets/pagina-web.png" alt="ARES Página Web" width="Auto" height="Auto" />
</div>

<!-- Features -->
### 🎯 Características

- **Captura Biométrica:** Lectura de señal ECG de un canal mediante el front-end AD8232.
- **Factor de Forma Ergonómico:** Hardware miniaturizado con componentes SMD para no interferir con la actividad física.
- **Conectividad:** Transmisión inalámbrica de la telemetría utilizando la pila Wi-Fi/BLE del ESP32.
- **Visualización Remota:** Interfaz gráfica web para el monitoreo en tiempo real por parte del usuario o personal médico.
- **Wearable Integrado:** Diseñado específicamente para funcionar dentro de la estructura de una prenda deportiva.

<div>&nbsp;</div>

<!-- Contact -->
## 🤝 Contacto

Para desarrollo, auditoría de hardware o consultas de inversión:

Mail - proyectoares26@gmail.com

Link del Proyecto: [https://github.com/impatrq/ARES](https://github.com/impatrq/ARES)