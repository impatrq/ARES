import { useI18n } from "@/lib/i18n";
import { GraduationCap, Instagram, Mail, MapPin } from "lucide-react";
import { Button } from "@/components/ui/button";

export const TeamContact = () => {
  const { t } = useI18n();
  return (
    <section id="team" className="relative py-24 md:py-32 bg-soft overflow-hidden">
      <div className="container">
        <div className="text-center max-w-2xl mx-auto mb-16">
          <span className="inline-block text-sm font-bold uppercase tracking-widest text-primary mb-4">
            {t.team.kicker}
          </span>
          <h2 className="text-4xl md:text-5xl font-bold tracking-tight text-foreground leading-tight">
            {t.team.title}
          </h2>
        </div>

        {/* Team grid */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-5 mb-16">
          {t.team.members.map((m, i) => (
            <div
              key={i}
              className="group bg-card border border-border rounded-2xl p-6 text-center hover:shadow-elegant hover:-translate-y-1 transition-all duration-500"
            >
              <div className="relative w-20 h-20 mx-auto mb-4">
                <div className="absolute inset-0 rounded-full bg-gradient-to-br from-primary to-accent opacity-90 group-hover:scale-110 transition-transform duration-500" />
                <div className="relative w-full h-full rounded-full flex items-center justify-center text-primary-foreground font-bold text-2xl">
                  {m.name[0]}
                </div>
              </div>
              <h3 className="text-base font-bold text-foreground mb-1">{m.name}</h3>
              <p className="text-xs text-muted-foreground">{m.role}</p>
            </div>
          ))}
        </div>

        {/* School + Contact */}
        <div className="grid lg:grid-cols-2 gap-5">
          {/* School */}
          <div className="relative overflow-hidden bg-gradient-to-br from-primary to-[hsl(354_55%_22%)] text-primary-foreground rounded-3xl p-8 md:p-10 shadow-elegant">
            <div className="absolute -right-20 -bottom-20 w-64 h-64 rounded-full bg-primary-foreground/10 blur-2xl" />
            <div className="relative">
              <span className="inline-block text-xs font-bold uppercase tracking-widest text-primary-foreground/70 mb-3">
                {t.team.schoolKicker}
              </span>
              <GraduationCap size={36} className="mb-4" />
              <h3 className="text-2xl md:text-3xl font-bold mb-2 leading-tight">{t.team.schoolName}</h3>
              <p className="text-primary-foreground/80">{t.team.schoolDetail}</p>
              <div className="flex items-center gap-2 mt-6 text-sm text-primary-foreground/70">
                <MapPin size={16} /> Quilmes, Buenos Aires · Argentina
              </div>
            </div>
          </div>

          {/* Contact */}
          <div className="bg-card border border-border rounded-3xl p-8 md:p-10 shadow-card-soft">
            <span className="inline-block text-xs font-bold uppercase tracking-widest text-primary mb-3">
              {t.team.contactKicker}
            </span>
            <h3 className="text-2xl md:text-3xl font-bold text-foreground mb-3 leading-tight">
              {t.team.contactTitle}
            </h3>
            <p className="text-muted-foreground mb-6">{t.team.contactDetail}</p>
            <div className="flex flex-col sm:flex-row gap-3">
              <Button asChild size="lg" className="flex-1">
                <a href="mailto:proyectoares26@gmail.com">
                  <Mail /> Email
                </a>
              </Button>
              <Button asChild size="lg" variant="outline" className="flex-1">
                <a href="https://instagram.com/ares.proyecto" target="_blank" rel="noopener noreferrer">
                  <Instagram /> Instagram
                </a>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};