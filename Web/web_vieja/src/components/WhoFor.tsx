import { useI18n } from "@/lib/i18n";
import { HeartPulse, UserRound, Stethoscope, Dumbbell, Trophy, Flame } from "lucide-react";

const icons = [HeartPulse, UserRound, Stethoscope, Dumbbell, Trophy, Flame];

export const WhoFor = () => {
  const { t } = useI18n();
  return (
    <section id="who" className="relative py-24 md:py-32 bg-soft overflow-hidden">
      <div className="container relative">
        <div className="text-center max-w-2xl mx-auto mb-16">
          <span className="inline-block text-sm font-bold uppercase tracking-widest text-primary mb-4">
            {t.who.kicker}
          </span>
          <h2 className="text-4xl md:text-5xl font-bold tracking-tight text-foreground mb-4 leading-tight">
            {t.who.title}
          </h2>
          <p className="text-base md:text-lg text-muted-foreground">{t.who.subtitle}</p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {t.who.items.map((item, i) => {
            const Icon = icons[i];
            return (
              <div
                key={i}
                className="group relative overflow-hidden bg-card border border-border rounded-2xl p-7 hover:shadow-elegant transition-all duration-500"
              >
                <div className="absolute -right-10 -top-10 w-32 h-32 rounded-full bg-primary/5 group-hover:bg-primary/10 transition-colors" />
                <div className="relative">
                  <div className="inline-flex p-3 rounded-xl bg-gradient-to-br from-primary to-accent text-primary-foreground mb-4 shadow-card-soft">
                    <Icon size={24} />
                  </div>
                  <h3 className="text-xl font-bold text-foreground mb-2">{item.t}</h3>
                  <p className="text-sm text-muted-foreground leading-relaxed">{item.d}</p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};