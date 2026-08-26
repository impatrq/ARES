import { createContext, useContext, useEffect, useState, ReactNode } from "react";

export type Lang = "es" | "en";

type Dict = {
  nav: { what: string; how: string; who: string; team: string; contact: string };
  hero: { tag: string; title: string; subtitle: string; pitch: string; ctaPrimary: string; ctaSecondary: string; badge: string };
  what: { kicker: string; title: string; problem: string; solution: string; stats: { value: string; label: string }[] };
  how: { kicker: string; title: string; subtitle: string; steps: { t: string; d: string }[] };
  who: { kicker: string; title: string; subtitle: string; items: { t: string; d: string }[] };
  tech: { kicker: string; title: string; subtitle: string; items: { t: string; d: string }[] };
  team: {
    kicker: string; title: string; members: { name: string; role: string }[];
    schoolKicker: string; schoolName: string; schoolDetail: string;
    contactKicker: string; contactTitle: string; contactDetail: string;
  };
  footer: { rights: string; made: string };
};

export const translations: Record<Lang, Dict> = {
  es: {
    nav: { what: "¿Qué es?", how: "¿Cómo funciona?", who: "¿Para quién?", team: "Equipo", contact: "Contacto" },
    hero: {
      tag: "Proyecto Final · EEST N°7 Quilmes",
      title: "A.R.E.S",
      subtitle: "Arrhythmia Real-time Evaluation System",
      pitch: "Tu corazón, monitoreado en tiempo real. Detección temprana de arritmias con Inteligencia Artificial, en un dispositivo portátil y accesible.",
      ctaPrimary: "Ver cómo funciona",
      ctaSecondary: "Conocer al equipo",
      badge: "Monitoreo activo",
    },
    what: {
      kicker: "¿Qué es ARES?",
      title: "Un guardián cardíaco que cabe en tu bolsillo",
      problem: "Las enfermedades cardiovasculares son la principal causa de muerte en el mundo. Muchas arritmias son silenciosas y se detectan demasiado tarde, cuando el daño ya está hecho.",
      solution: "ARES combina sensores médicos profesionales con Inteligencia Artificial embebida para analizar tu actividad cardíaca las 24 horas y avisar al instante a familiares o personal médico ante cualquier anomalía.",
      stats: [
        { value: "108 USD", label: "Costo total accesible" },
        { value: "24/7", label: "Monitoreo en tiempo real" },
        { value: "0", label: "Implantes — 100% no invasivo" },
      ],
    },
    how: {
      kicker: "¿Cómo funciona?",
      title: "De tu pecho a tu familia, en segundos",
      subtitle: "Seis pasos automáticos que pueden salvar una vida.",
      steps: [
        { t: "Electrodos ECG", d: "Tres electrodos (RA, LA, RL) captan la actividad eléctrica del corazón desde el pecho." },
        { t: "Sensor AD8232", d: "Amplifica y limpia la señal cardíaca con calidad médica profesional." },
        { t: "Microcontrolador ESP32", d: "Filtra, digitaliza y procesa la señal en tiempo real con bajo consumo." },
        { t: "Inteligencia Artificial", d: "Un modelo embebido analiza el patrón y detecta arritmias o anomalías." },
        { t: "Bluetooth + GPS", d: "Si detecta una alerta, envía la señal junto a tu ubicación exacta al instante." },
        { t: "App móvil", d: "Familiares, médicos o servicios de emergencia reciben la notificación inmediatamente." },
      ],
    },
    who: {
      kicker: "¿A quién está dirigido?",
      title: "Pensado para quienes más lo necesitan",
      subtitle: "ARES está diseñado para acompañar a personas en situaciones donde cada segundo cuenta.",
      items: [
        { t: "Pacientes cardíacos", d: "Seguimiento continuo para personas con condiciones cardíacas previas." },
        { t: "Adultos mayores", d: "Tranquilidad para ellos y sus familias, en casa o fuera de ella." },
        { t: "Post-tratamiento", d: "Monitoreo durante la recuperación tras cirugías o eventos cardíacos." },
        { t: "Deportistas", d: "Control del esfuerzo y prevención de eventos durante el entrenamiento." },
        { t: "Alto rendimiento", d: "Centros deportivos profesionales que requieren datos cardíacos en vivo." },
        { t: "Trabajos de riesgo", d: "Bomberos, mineros, rescatistas y choferes de larga distancia." },
      ],
    },
    tech: {
      kicker: "Tecnología",
      title: "Componentes de calidad médica",
      subtitle: "Hardware confiable + software inteligente.",
      items: [
        { t: "Sensor AD8232", d: "Front-end ECG de grado clínico." },
        { t: "ESP32", d: "Microcontrolador WiFi + Bluetooth." },
        { t: "GPS NEO-6M", d: "Geolocalización precisa de alertas." },
        { t: "Batería 18650", d: "Autonomía prolongada y recargable." },
        { t: "App móvil", d: "Notificaciones en tiempo real." },
      ],
    },
    team: {
      kicker: "Equipo",
      title: "Hecho por estudiantes, con estándares profesionales",
      members: [
        { name: "Balbastro", role: "Hardware & Sensores" },
        { name: "Celso", role: "Firmware & ESP32" },
        { name: "D'Abundo", role: "IA & Procesamiento de señal" },
        { name: "Leones", role: "App móvil & Conectividad" },
      ],
      schoolKicker: "Escuela",
      schoolName: "EEST N°7 — Taller Regional Quilmes",
      schoolDetail: "Prácticas Profesionalizantes · Especialidad Aviónica",
      contactKicker: "Contacto",
      contactTitle: "¿Querés saber más sobre ARES?",
      contactDetail: "Escribinos o seguinos en redes para conocer el avance del proyecto.",
    },
    footer: { rights: "Todos los derechos reservados.", made: "Hecho con dedicación por el equipo ARES" },
  },
  en: {
    nav: { what: "What is it?", how: "How it works?", who: "Who is it for?", team: "Team", contact: "Contact" },
    hero: {
      tag: "Final Project · EEST N°7 Quilmes",
      title: "A.R.E.S",
      subtitle: "Arrhythmia Real-time Evaluation System",
      pitch: "Your heart, monitored in real time. Early arrhythmia detection powered by AI, in a portable and affordable device.",
      ctaPrimary: "See how it works",
      ctaSecondary: "Meet the team",
      badge: "Live monitoring",
    },
    what: {
      kicker: "What is ARES?",
      title: "A cardiac guardian that fits in your pocket",
      problem: "Cardiovascular diseases are the world's leading cause of death. Many arrhythmias are silent and detected too late, when the damage is already done.",
      solution: "ARES combines professional medical sensors with embedded Artificial Intelligence to analyze your cardiac activity 24/7 and instantly alert family members or medical staff at the first sign of an anomaly.",
      stats: [
        { value: "USD 108", label: "Affordable total cost" },
        { value: "24/7", label: "Real-time monitoring" },
        { value: "0", label: "Implants — 100% non-invasive" },
      ],
    },
    how: {
      kicker: "How it works?",
      title: "From your chest to your family, in seconds",
      subtitle: "Six automatic steps that can save a life.",
      steps: [
        { t: "ECG Electrodes", d: "Three electrodes (RA, LA, RL) capture the heart's electrical activity from the chest." },
        { t: "AD8232 Sensor", d: "Amplifies and cleans the cardiac signal with medical-grade quality." },
        { t: "ESP32 Microcontroller", d: "Filters, digitizes and processes the signal in real time with low power." },
        { t: "Artificial Intelligence", d: "An embedded model analyzes the pattern and detects arrhythmias or anomalies." },
        { t: "Bluetooth + GPS", d: "If an alert is triggered, it instantly sends the signal along with your exact location." },
        { t: "Mobile app", d: "Family, doctors or emergency services receive the notification immediately." },
      ],
    },
    who: {
      kicker: "Who is it for?",
      title: "Built for those who need it most",
      subtitle: "ARES is designed to support people in situations where every second counts.",
      items: [
        { t: "Cardiac patients", d: "Continuous tracking for people with prior cardiac conditions." },
        { t: "Older adults", d: "Peace of mind for them and their families, at home or away." },
        { t: "Post-treatment", d: "Monitoring during recovery after surgery or cardiac events." },
        { t: "Athletes", d: "Effort control and prevention of events during training." },
        { t: "High performance", d: "Professional sports centers that require live cardiac data." },
        { t: "High-risk jobs", d: "Firefighters, miners, rescuers and long-distance drivers." },
      ],
    },
    tech: {
      kicker: "Technology",
      title: "Medical-grade components",
      subtitle: "Reliable hardware + intelligent software.",
      items: [
        { t: "AD8232 Sensor", d: "Clinical-grade ECG front-end." },
        { t: "ESP32", d: "WiFi + Bluetooth microcontroller." },
        { t: "NEO-6M GPS", d: "Accurate alert geolocation." },
        { t: "18650 Battery", d: "Long-lasting and rechargeable." },
        { t: "Mobile app", d: "Real-time notifications." },
      ],
    },
    team: {
      kicker: "Team",
      title: "Made by students, with professional standards",
      members: [
        { name: "Balbastro", role: "Hardware & Sensors" },
        { name: "Celso", role: "Firmware & ESP32" },
        { name: "D'Abundo", role: "AI & Signal processing" },
        { name: "Leones", role: "Mobile app & Connectivity" },
      ],
      schoolKicker: "School",
      schoolName: "EEST N°7 — Quilmes Regional Workshop",
      schoolDetail: "Professional Practices · Avionics Specialty",
      contactKicker: "Contact",
      contactTitle: "Want to know more about ARES?",
      contactDetail: "Reach out or follow us on social media to see the project's progress.",
    },
    footer: { rights: "All rights reserved.", made: "Crafted with dedication by the ARES team" },
  },
};

type Ctx = { lang: Lang; setLang: (l: Lang) => void; t: Dict };
const I18nContext = createContext<Ctx | null>(null);

export const I18nProvider = ({ children }: { children: ReactNode }) => {
  const [lang, setLangState] = useState<Lang>(() => {
    if (typeof window === "undefined") return "es";
    return (localStorage.getItem("ares-lang") as Lang) || "es";
  });
  const setLang = (l: Lang) => {
    setLangState(l);
    localStorage.setItem("ares-lang", l);
  };
  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);
  return (
    <I18nContext.Provider value={{ lang, setLang, t: translations[lang] }}>
      {children}
    </I18nContext.Provider>
  );
};

export const useI18n = () => {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error("useI18n must be used inside I18nProvider");
  return ctx;
};