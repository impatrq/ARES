import { I18nProvider } from "@/lib/i18n";
import { Navbar } from "@/components/Navbar";
import { Hero } from "@/components/Hero";
import { WhatIsAres } from "@/components/WhatIsAres";
import { HowItWorks } from "@/components/HowItWorks";
import { WhoFor } from "@/components/WhoFor";
import { Tech } from "@/components/Tech";
import { TeamContact } from "@/components/TeamContact";
import { Footer } from "@/components/Footer";

const Index = () => {
  return (
    <I18nProvider>
      <main className="min-h-screen bg-background text-foreground">
        <Navbar />
        <Hero />
        <WhatIsAres />
        <HowItWorks />
        <WhoFor />
        <Tech />
        <TeamContact />
        <Footer />
      </main>
    </I18nProvider>
  );
};

export default Index;
