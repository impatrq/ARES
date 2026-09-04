import { useI18n } from "@/lib/i18n";
import { Zap, Cpu, Brain, Radio, Smartphone, HeartPulse } from "lucide-react";
import { EcgLine } from "./EcgLine";

const icons = [HeartPulse, Zap, Cpu, Brain, Radio, Smartphone];

export const HowItWorks = () => {
  const { t } = useI18n();
  return (
    <section id="how" className="relative py-24 md:py-32 bg-background overflow-hidden">
      <div className="absolute inset-x-0 top-1/2 h-24 opacity-[0.07] text-primary pointer-events-none">
        <EcgLine className="w-full h-full" strokeWidth={2} />
      </div>

      <div className="container relative">
        <div className="text-center max-w-2xl mx-auto mb-16">
          <span className="inline-block text-sm font-bold uppercase tracking-widest text-primary mb-4">
            {t.how.kicker}
          </span>
          <h2 className="text-4xl md:text-5xl font-bold tracking-tight text-foreground mb-4 leading-tight">
            {t.how.title}
          </h2>
          <p className="text-base md:text-lg text-muted-foreground">{t.how.subtitle}</p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {t.how.steps.map((step, i) => {
            const Icon = icons[i];
            return (
              <div
                key={i}
                className="group relative bg-card border border-border rounded-2xl p-6 hover:border-primary/40 hover:shadow-elegant hover:-translate-y-1 transition-all duration-500"
              >
                <div className="absolute -top-3 -left-3 w-10 h-10 rounded-xl bg-gradient-to-br from-primary to-accent text-primary-foreground font-bold flex items-center justify-center shadow-card-soft">
                  {String(i + 1).padStart(2, "0")}
                </div>
                <div className="w-14 h-14 rounded-xl bg-primary/10 flex items-center justify-center mb-5 group-hover:bg-primary group-hover:text-primary-foreground transition-colors duration-500">
                  <Icon className="text-primary group-hover:text-primary-foreground transition-colors" size={26} />
                </div>
                <h3 className="text-lg font-bold text-foreground mb-2">{step.t}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{step.d}</p>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};