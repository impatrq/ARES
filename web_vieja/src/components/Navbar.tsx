import { useEffect, useState } from "react";
import { Menu, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useI18n } from "@/lib/i18n";
import logoRect from "@/assets/ares-logo-rect-transparent.png";

const links = [
  { id: "what", key: "what" as const },
  { id: "how", key: "how" as const },
  { id: "who", key: "who" as const },
  { id: "team", key: "team" as const },
];

export const Navbar = () => {
  const { lang, setLang, t } = useI18n();
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const go = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
    setOpen(false);
  };

  return (
    <header
      className={`fixed top-0 inset-x-0 z-50 transition-shadow duration-500 bg-background/95 backdrop-blur-xl border-b border-border ${
        scrolled ? "shadow-sm" : ""
      }`}
    >
      <nav className="container flex items-center justify-between h-16 md:h-20">
        <button onClick={() => go("hero")} className="flex items-center gap-2 group" aria-label="ARES home">
          <img
            src={logoRect}
            alt="ARES logo"
            className="h-12 md:h-16 w-auto transition-transform group-hover:scale-105"
          />
        </button>

        <div className="hidden md:flex items-center gap-1">
          {links.map((l) => (
            <button
              key={l.id}
              onClick={() => go(l.id)}
              className="px-4 py-2 text-sm font-medium text-foreground/75 hover:text-primary transition-colors relative group"
            >
              {t.nav[l.key]}
              <span className="absolute inset-x-4 -bottom-0.5 h-0.5 bg-primary scale-x-0 group-hover:scale-x-100 origin-left transition-transform" />
            </button>
          ))}
        </div>

        <div className="flex items-center gap-2 md:gap-3">
          <div className="flex items-center text-xs font-semibold rounded-full border border-border overflow-hidden">
            <button
              onClick={() => setLang("es")}
              className={`px-2.5 py-1 transition-colors ${lang === "es" ? "bg-primary text-primary-foreground" : "text-foreground/60 hover:text-foreground"}`}
            >
              ES
            </button>
            <button
              onClick={() => setLang("en")}
              className={`px-2.5 py-1 transition-colors ${lang === "en" ? "bg-primary text-primary-foreground" : "text-foreground/60 hover:text-foreground"}`}
            >
              EN
            </button>
          </div>
          <Button size="sm" onClick={() => go("team")} className="hidden sm:inline-flex">
            {t.nav.contact}
          </Button>
          <button
            className="md:hidden p-2 text-foreground"
            onClick={() => setOpen((v) => !v)}
            aria-label="menu"
          >
            {open ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </nav>

      {open && (
        <div className="md:hidden border-t border-border bg-background/95 backdrop-blur-xl animate-fade-in">
          <div className="container py-4 flex flex-col gap-1">
            {links.map((l) => (
              <button
                key={l.id}
                onClick={() => go(l.id)}
                className="text-left px-3 py-3 text-base font-medium text-foreground/80 hover:bg-muted rounded-lg"
              >
                {t.nav[l.key]}
              </button>
            ))}
            <Button onClick={() => go("team")} className="mt-2">
              {t.nav.contact}
            </Button>
          </div>
        </div>
      )}
    </header>
  );
};