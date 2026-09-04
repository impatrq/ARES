
# A.R.E.S — Landing Page del Proyecto

Sitio one-page bilingüe (ES/EN) con estética **médico-tecnológica premium**: profesional como un producto real listo para vender, pero claro y accesible para que cualquiera entienda qué hace ARES en 30 segundos. Paleta basada en el bordó del logo (#7A2A2E aprox.) sobre blanco/marfil, con acentos de línea ECG en movimiento, tipografía bold tipo "Inter/Space Grotesk" y micro-animaciones suaves.

## Branding y Estilo
- **Colores**: bordó ARES como primario, blanco hueso de fondo, gris pizarra para texto, verde menta sutil para "estado saludable" y rojo alerta para "anomalía detectada".
- **Logo ARES**: usado en navbar (versión rectangular) y en hero (versión circular grande).
- **Detalle visual recurrente**: línea de ECG animada (SVG) atravesando secciones como hilo conductor.
- **Selector de idioma ES/EN** fijo en la navbar (toggle simple, sin recargar).

## Secciones (scroll vertical)

### 1. Navbar fija
Logo ARES + links (¿Qué es? · Cómo funciona · ¿Para quién? · Equipo) + toggle ES/EN + botón "Contacto".

### 2. Hero
- Logo circular grande a la izquierda, a la derecha:
  - Título XXL: **A.R.E.S**
  - Subtítulo: *Arrhythmia Real-time Evaluation System*
  - Frase gancho: "Tu corazón, monitoreado en tiempo real. Detección temprana de arritmias con IA, en un dispositivo portátil y accesible."
  - CTAs: "Ver cómo funciona" + "Conocer al equipo"
- Fondo con línea ECG animada de lado a lado.

### 3. ¿Qué es ARES?
Bloque de 2 columnas: texto breve explicando el problema (las enfermedades cardiovasculares son la principal causa de muerte y muchas arritmias son silenciosas) y la solución (dispositivo portátil + IA que alerta a tiempo). Tres tarjetas de stats:
- **108 USD** costo total
- **Tiempo real** monitoreo continuo
- **Sin implantes** 100% no invasivo

### 4. Cómo funciona (paso a paso)
Diagrama horizontal/vertical responsive con 6 pasos animados al scroll, cada uno con icono custom:
1. **Electrodos ECG** (RA/LA/RL en el pecho)
2. **Sensor AD8232** capta la señal eléctrica
3. **Microcontrolador ESP32** filtra y digitaliza
4. **IA embebida** detecta patrones anormales
5. **Bluetooth + GPS** envía alerta y ubicación
6. **App móvil** notifica a familiares/médicos

Cada paso: tarjeta con icono, título y 1–2 líneas. Líneas conectoras animadas tipo ECG entre tarjetas.

### 5. ¿A quién está dirigido?
Grid de 6 tarjetas con icono e imagen sutil:
- Pacientes cardíacos · Adultos mayores · Post-tratamiento · Deportistas · Centros de alto rendimiento · Trabajos de alto riesgo (bomberos, mineros, rescatistas, choferes de larga distancia).

### 6. Tecnología y Componentes
Mini-sección visual con los componentes clave (AD8232, ESP32, GPS NEO-6M, batería 18650, app móvil) en cards con iconos — refuerza credibilidad técnica sin abrumar.

### 7. Equipo + Escuela + Contacto
- Bloque del equipo: 4 tarjetas con los integrantes (Balbastro, Celso, D'Abundo, Leones) y su rol en el proyecto.
- Bloque de la escuela: **EEST N°7 — Taller Regional Quilmes — Prácticas Profesionalizantes, Especialidad Aviónica**.
- Contacto: links a Instagram (placeholder editable) y email del equipo.

### 8. Footer
Logo pequeño, copyright, créditos del equipo, año.

## Funcionalidad
- **Bilingüe ES/EN** con toggle (todo el copy traducido, persiste en localStorage).
- **Animaciones al scroll** suaves (fade-in, líneas ECG que se "dibujan").
- **100% responsive** — mobile-first (la mayoría verá esto desde Instagram en el celular).
- **SEO básico**: title, meta description, og-image con el logo ARES.

## Assets a integrar
- Logo circular ARES (hero) y logo rectangular ARES (navbar) — ambos ya provistos.
- Iconos vectoriales (lucide-react) para cada paso y cada público objetivo.
- Ilustraciones SVG simples (línea ECG, corazón, ondas) generadas inline para mantener todo liviano.

Resultado: una landing **vendedora, profesional y didáctica** que sirve tanto para mostrar a un jurado/inversor como para compartir el link en redes y que cualquiera entienda el proyecto al instante.
