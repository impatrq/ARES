import { useI18n } from "@/lib/i18n";
import logoRect from "@/assets/ares-logo-rect.png";

export const Footer = () => {
  const { t } = useI18n();
  return (
    <footer className="bg-[hsl(354_60%_8%)] text-primary-foreground/80 py-10">
      <div className="container flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <img src={logoRect} alt="ARES" className="h-9 w-auto brightness-0 invert opacity-90" />
        </div>
        <p className="text-sm text-center md:text-right">
          © {new Date().getFullYear()} A.R.E.S — {t.footer.rights}
          <br className="md:hidden" />
          <span className="text-primary-foreground/50"> · {t.footer.made}</span>
        </p>
      </div>
    </footer>
  );
};