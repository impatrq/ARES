import { useI18n } from "@/lib/i18n";
import { Activity, Cpu, MapPin, Battery, Smartphone } from "lucide-react";

const icons = [Activity, Cpu, MapPin, Battery, Smartphone];

export const Tech = () => {
  const { t } = useI18n();
  return (
    <section className="relative py-20 md:py-28 bg-background overflow-hidden">
      <div className="container">
        <div className="text-center max-w-2xl mx-auto mb-12">
          <span className="inline-block text-sm font-bold uppercase tracking-widest text-primary mb-4">
            {t.tech.kicker}
          </span>
          <h2 className="text-3xl md:text-4xl font-bold tracking-tight text-foreground mb-3 leading-tight">
            {t.tech.title}
          </h2>
          <p className="text-base text-muted-foreground">{t.tech.subtitle}</p>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          {t.tech.items.map((item, i) => {
            const Icon = icons[i];
            return (
              <div
                key={i}
                className="bg-gradient-to-br from-card to-muted/40 border border-border rounded-2xl p-5 text-center hover:shadow-card-soft hover:-translate-y-1 transition-all duration-300"
              >
                <div className="inline-flex p-3 rounded-xl bg-primary/10 text-primary mb-3">
                  <Icon size={22} />
                </div>
                <h3 className="text-sm font-bold text-foreground mb-1">{item.t}</h3>
                <p className="text-xs text-muted-foreground">{item.d}</p>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
};