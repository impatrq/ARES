import { Button } from "@/components/ui/button";
import { Heart, ArrowRight, Activity } from "lucide-react";
import { useI18n } from "@/lib/i18n";
import { EcgLine } from "./EcgLine";
import logoCircle from "@/assets/ares-logo-rect-transparent.png";
import heroBg from "@/assets/hero-bg.jpg";

export const Hero = () => {
  const { t } = useI18n();
  const go = (id: string) => document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });

  return (
    <section
      id="hero"
      className="relative min-h-screen flex items-center pt-24 pb-16 overflow-hidden"
      style={{
        backgroundImage: `linear-gradient(135deg, hsl(354 60% 12% / 0.92), hsl(354 55% 22% / 0.88)), url(${heroBg})`,
        backgroundSize: "cover",
        backgroundPosition: "center",
      }}
    >
      {/* Decorative glows */}
      <div className="absolute -top-40 -right-40 w-[600px] h-[600px] rounded-full bg-[hsl(354_70%_55%/0.25)] blur-3xl pointer-events-none" />
      <div className="absolute -bottom-32 -left-32 w-[500px] h-[500px] rounded-full bg-[hsl(354_70%_45%/0.18)] blur-3xl pointer-events-none" />

      {/* ECG line crossing */}
      <div className="absolute inset-x-0 top-1/2 -translate-y-1/2 h-32 opacity-40 text-[hsl(354_80%_70%)] pointer-events-none">
        <EcgLine className="w-full h-full" strokeWidth={1.5} />
      </div>

      <div className="container relative grid lg:grid-cols-12 gap-10 lg:gap-14 items-center">
        {/* Logo column */}
        <div className="lg:col-span-5 flex justify-center lg:justify-start animate-fade-in-left">
          <div className="relative">
            <div className="absolute inset-0 rounded-full bg-[hsl(354_80%_60%/0.45)] blur-3xl scale-110 animate-pulse" />
            <img
              src={logoCircle}
              alt="ARES — Arrhythmia Real-time Evaluation System"
              width={1024}
              height={400}
              className="relative w-full max-w-md sm:max-w-lg lg:max-w-2xl h-auto rounded-2xl object-contain shadow-elegant animate-float"
            />
            <div className="absolute bottom-2 right-2 sm:bottom-6 sm:right-6 bg-background text-foreground rounded-full px-3 py-2 shadow-card-soft flex items-center gap-2 text-xs font-semibold">
              <span className="relative flex h-2.5 w-2.5">
                <span className="absolute inline-flex h-full w-full rounded-full bg-healthy opacity-75 animate-ping" />
                <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-healthy" />
              </span>
              {t.hero.badge}
            </div>
          </div>
        </div>

        {/* Content column */}
        <div className="lg:col-span-7 text-primary-foreground animate-fade-in-right">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary-foreground/10 border border-primary-foreground/20 backdrop-blur-sm text-xs font-medium mb-6">
            <Activity size={14} className="text-[hsl(354_80%_75%)]" />
            {t.hero.tag}
          </div>

          <h1 className="text-6xl sm:text-7xl md:text-8xl lg:text-9xl font-black tracking-tighter mb-3 leading-none">
            {t.hero.title}
          </h1>
          <p className="text-lg sm:text-xl md:text-2xl font-light text-primary-foreground/85 italic mb-6">
            {t.hero.subtitle}
          </p>
          <p className="text-base sm:text-lg text-primary-foreground/80 max-w-xl mb-8 leading-relaxed">
            {t.hero.pitch}
          </p>

          <div className="flex flex-col sm:flex-row gap-3">
            <Button
              size="lg"
              onClick={() => go("how")}
              className="bg-primary-foreground text-primary hover:bg-primary-foreground/90 font-semibold group"
            >
              {t.hero.ctaPrimary}
              <ArrowRight className="transition-transform group-hover:translate-x-1" />
            </Button>
            <Button
              size="lg"
              variant="outline"
              onClick={() => go("team")}
              className="bg-transparent text-primary-foreground border-primary-foreground/40 hover:bg-primary-foreground/10 hover:text-primary-foreground"
            >
              <Heart className="animate-pulse-heart" />
              {t.hero.ctaSecondary}
            </Button>
          </div>
        </div>
      </div>
    </section>
  );
};