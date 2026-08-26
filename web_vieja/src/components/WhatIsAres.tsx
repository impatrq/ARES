import { useI18n } from "@/lib/i18n";
import { ShieldCheck, Clock, HeartPulse } from "lucide-react";
import deviceImg from "@/assets/device-mockup.jpg";

export const WhatIsAres = () => {
  const { t } = useI18n();
  const icons = [HeartPulse, Clock, ShieldCheck];

  return (
    <section id="what" className="relative py-24 md:py-32 bg-soft overflow-hidden">
      <div className="container">
        <div className="grid lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          <div className="relative order-2 lg:order-1">
            <div className="absolute -inset-6 bg-gradient-to-br from-primary/10 to-accent/10 rounded-3xl blur-2xl" />
            <div className="relative rounded-3xl overflow-hidden shadow-elegant bg-card aspect-square">
              <img
                src={deviceImg}
                alt="ARES wearable device"
                width={1024}
                height={1024}
                loading="lazy"
                className="w-full h-full object-cover"
              />
            </div>
            <div className="absolute -bottom-6 -right-6 bg-card rounded-2xl p-4 shadow-card-soft border border-border max-w-[200px] animate-float">
              <div className="flex items-center gap-2 text-xs text-muted-foreground mb-1">
                <span className="relative flex h-2 w-2">
                  <span className="absolute inline-flex h-full w-full rounded-full bg-healthy opacity-75 animate-ping" />
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-healthy" />
                </span>
                BPM
              </div>
              <div className="text-2xl font-bold text-foreground">72<span className="text-sm font-normal text-muted-foreground ml-1">/min</span></div>
            </div>
          </div>

          <div className="order-1 lg:order-2">
            <span className="inline-block text-sm font-bold uppercase tracking-widest text-primary mb-4">
              {t.what.kicker}
            </span>
            <h2 className="text-4xl md:text-5xl font-bold tracking-tight text-foreground mb-6 leading-tight">
              {t.what.title}
            </h2>
            <p className="text-base md:text-lg text-muted-foreground leading-relaxed mb-4">
              {t.what.problem}
            </p>
            <p className="text-base md:text-lg text-foreground leading-relaxed mb-8">
              {t.what.solution}
            </p>

            <div className="grid sm:grid-cols-3 gap-4">
              {t.what.stats.map((s, i) => {
                const Icon = icons[i];
                return (
                  <div
                    key={i}
                    className="bg-card border border-border rounded-2xl p-5 hover:shadow-card-soft hover:-translate-y-1 transition-all duration-300"
                  >
                    <Icon className="text-primary mb-3" size={22} />
                    <div className="text-2xl font-bold text-foreground leading-tight">{s.value}</div>
                    <div className="text-xs text-muted-foreground mt-1">{s.label}</div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};