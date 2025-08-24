"use client";

// SDIaaS.io Lead Landing Page (framework-agnostic React)
// Fixes:
// - Removed broken static import of logo; now uses public-path string "/brexa-logo.jpg.png" so build won't fail if the file isn't bundled.
// - Added defensive fallback if logo is missing (renders a styled "B").
// - Replaced shadcn/ui Card/Button with local components to avoid missing-dependency errors.
// - Implemented working anchors (#why, #features, #contact) and smooth scrolling.
// - Added basic runtime "tests" (console.assert) to verify endpoints and anchors in dev.
// - Kept Formspree integration and improved error handling.

import { useEffect, useMemo, useState } from "react";
import { Check, Loader2, Rocket, ShieldCheck, FlaskConical, Cpu } from "lucide-react";

// ---- Brand ----
const BRAND = {
  navy: "#0b2e4f",
  blue: "#51b4ff",
  green: "#10b981",
  bg: "#f6f9fc",
};

// Centralize Formspree endpoint so we can validate it in dev tests
const FORMSPREE_ENDPOINT = "https://formspree.io/f/mnnbaarq";

// ---- Lightweight UI primitives (to avoid external deps) ----
function Card({ className = "", children }) {
  return (
    <div className={`rounded-2xl shadow-lg border border-slate-200 bg-white ${className}`}>{children}</div>
  );
}
function CardContent({ className = "", children }) {
  return <div className={`p-6 md:p-8 ${className}`}>{children}</div>;
}
function Button({ className = "", disabled, onClick, children, type = "button" }) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      className={`h-11 rounded-xl px-4 font-medium text-white flex items-center justify-center gap-2 transition-opacity ${
        disabled ? "opacity-60 cursor-not-allowed" : "hover:opacity-90"
      } ${className}`}
      style={{ background: disabled ? "#a3a3a3" : BRAND.navy }}
    >
      {children}
    </button>
  );
}

// ---- Logo ----
function Logo() {
  const [broken, setBroken] = useState(false);
  return (
    <div className="flex items-center gap-3">
      {broken ? (
        <div
          className="w-10 h-10 rounded-2xl flex items-center justify-center text-white text-lg font-bold"
          style={{ background: BRAND.navy }}
          aria-label="Brexa logo fallback"
        >
          B
        </div>
      ) : (
        // Use public path. Place `brexa-logo.jpg.png` in your project's `/public` folder.
        <img
          src="/brexa-logo.jpg.png"
          width={40}
          height={40}
          alt="Brexa SDIaaS"
          onError={() => setBroken(true)}
          className="rounded-2xl object-contain"
        />
      )}
      <div className="leading-tight">
        <div className="text-lg font-semibold" style={{ color: BRAND.navy }}>Brexa SDIaaS</div>
        <div className="text-xs text-slate-500">Infrastructure Redefined</div>
      </div>
    </div>
  );
}

export default function Landing() {
  const [loading, setLoading] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState(null);
  const [values, setValues] = useState({
    name: "",
    email: "",
    company: "",
    phone: "",
    interest: "",
    notes: "",
    website: "", // honeypot
  });

  const utm = useMemo(() => {
    if (typeof window === "undefined") return {};
    const params = new URLSearchParams(window.location.search);
    const keys = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content"];
    const obj = {};
    keys.forEach((k) => {
      const v = params.get(k);
      if (v) obj[k] = v;
    });
    return obj;
  }, []);

  useEffect(() => {
    document.title = "SDIaaS by Brexa — Regulatory-first, Science-native, AI-ready";

    // --- Dev-only smoke tests ---
    if (process.env.NODE_ENV !== "production" && typeof window !== "undefined") {
      console.assert(
        FORMSPREE_ENDPOINT.startsWith("https://formspree.io/f/"),
        "Form endpoint looks wrong: ",
        FORMSPREE_ENDPOINT
      );
      const ids = ["why", "features", "contact"];
      const missing = ids.filter((id) => !document.getElementById(id));
      console.assert(missing.length === 0, "Missing anchor section(s):", missing);
    }
  }, []);

  const disabled = loading || !values.email || !values.name;

  async function submit(e) {
    e.preventDefault();
    setError(null);
    if (values.website) return; // honeypot
    setLoading(true);
    try {
      const res = await fetch(FORMSPREE_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ ...values, utm }),
      });
      if (!res.ok) throw new Error("Submission failed");
      setSubmitted(true);
      setValues({ name: "", email: "", company: "", phone: "", interest: "", notes: "", website: "" });
    } catch (err) {
      setError(err?.message || "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen scroll-smooth flex flex-col justify-between" style={{ background: BRAND.bg }}>
      <div>
        {/* Header */}
        <header className="max-w-6xl mx-auto px-6 py-5 flex items-center justify-between">
          <Logo />
          <nav className="hidden md:flex items-center gap-6 text-sm">
            <a data-testid="link-why" href="#why" className="text-slate-600 hover:text-slate-900">Why SDIaaS</a>
            <a data-testid="link-features" href="#features" className="text-slate-600 hover:text-slate-900">Features</a>
            <a data-testid="link-contact" href="#contact" className="text-slate-600 hover:text-slate-900">Request Early Access</a>
          </nav>
        </header>

        {/* Hero + Form */}
        <section className="max-w-6xl mx-auto px-6 pt-6 pb-16 grid lg:grid-cols-2 gap-10 items-center">
          <div>
            <h1 className="text-4xl md:text-5xl font-bold leading-tight" style={{ color: BRAND.navy }}>
              Regulatory-first. Science-native. <span style={{ color: BRAND.green }}>AI-ready.</span>
            </h1>
            <p className="mt-4 text-slate-600 text-lg">
              SDIaaS by Brexa unifies instrument, ELN, and LIMS data into compliant, AI-ready datasets with dashboards for QC, batch genealogy, and bioreactor ops.
            </p>
            <ul className="mt-6 space-y-2 text-slate-700">
              <li className="flex items-center gap-2"><ShieldCheck className="w-5 h-5"/> 21 CFR Part 11 & ALCOA+ by design</li>
              <li className="flex items-center gap-2"><Cpu className="w-5 h-5"/> Harmonized data contracts for analytics/ML</li>
              <li className="flex items-center gap-2"><FlaskConical className="w-5 h-5"/> 200+ instruments & ELN/LIMS connectors</li>
            </ul>
          </div>

          <Card id="contact">
            <CardContent>
              {submitted ? (
                <div className="text-center">
                  <div className="mx-auto w-14 h-14 rounded-full flex items-center justify-center mb-4" style={{ background: BRAND.green }}>
                    <Check className="w-7 h-7 text-white" />
                  </div>
                  <h3 className="text-xl font-semibold" style={{ color: BRAND.navy }}>Thanks! You're on the early-access list.</h3>
                  <p className="text-slate-600 mt-2">We'll reach out within 1–2 business days to schedule a discovery call.</p>
                </div>
              ) : (
                <form onSubmit={submit} className="space-y-4">
                  <h3 className="text-xl font-semibold" style={{ color: BRAND.navy }}>Request Early Access</h3>
                  <p className="text-slate-600 text-sm">Tell us a bit about your team. We'll follow up with next steps.</p>

                  {/* Honeypot */}
                  <input type="text" name="website" autoComplete="off" className="hidden" value={values.website} onChange={(e)=>setValues((v)=>({ ...v, website: e.target.value }))} />

                  <div className="grid md:grid-cols-2 gap-3">
                    <input className="px-3 py-2 rounded-xl border border-slate-200 w-full" placeholder="Full name*" value={values.name} onChange={(e)=>setValues((v)=>({ ...v, name: e.target.value }))} />
                    <input className="px-3 py-2 rounded-xl border border-slate-200 w-full" placeholder="Work email*" type="email" value={values.email} onChange={(e)=>setValues((v)=>({ ...v, email: e.target.value }))} />
                  </div>
                  <div className="grid md:grid-cols-2 gap-3">
                    <input className="px-3 py-2 rounded-xl border border-slate-200 w-full" placeholder="Company" value={values.company} onChange={(e)=>setValues((v)=>({ ...v, company: e.target.value }))} />
                    <input className="px-3 py-2 rounded-xl border border-slate-200 w-full" placeholder="Phone" type="tel" value={values.phone} onChange={(e)=>setValues((v)=>({ ...v, phone: e.target.value }))} />
                  </div>
                  <select className="px-3 py-2 rounded-xl border border-slate-200 w-full" value={values.interest} onChange={(e)=>setValues((v)=>({ ...v, interest: e.target.value }))}>
                    <option value="">Primary interest</option>
                    <option>QC dashboards & Part 11</option>
                    <option>Bioreactor ops (soft sensors, golden batch)</option>
                    <option>LIMS/ELN/instrument integration</option>
                    <option>AI/ML for process & release</option>
                  </select>
                  <textarea className="px-3 py-2 rounded-xl border border-slate-200 w-full" rows={4} placeholder="Notes (assays, instruments, timelines)" value={values.notes} onChange={(e)=>setValues((v)=>({ ...v, notes: e.target.value }))} />

                  {error && <div className="text-sm text-red-600">{error}</div>}

                  <Button disabled={disabled} type="submit" className="w-full">
                    {loading ? (<><Loader2 className="w-4 h-4 animate-spin"/>Submitting…</>) : (<><Rocket className="w-4 h-4"/> Request early access</>)}
                  </Button>
                  <p className="text-xs text-slate-500 text-center">We’ll never sell your data. By submitting, you agree to our privacy policy.</p>
                </form>
              )}
            </CardContent>
          </Card>
        </section>

        {/* Why */}
        <section id="why" className="max-w-6xl mx-auto px-6 pb-12">
          <div className="grid md:grid-cols-3 gap-4">
            {[
              { title: "Regulatory-first", desc: "21 CFR Part 11, ALCOA+, audit trails, and validation are built in." },
              { title: "Science-native", desc: "Data contracts for HPLC, MS, qPCR, bioreactors; 200+ connectors to ELN/LIMS/instruments." },
              { title: "AI-ready", desc: "Harmonized, versioned datasets for anomaly detection, soft sensors, and release risk scoring." },
            ].map((b, i) => (
              <div key={i} className="rounded-2xl bg-white p-6 shadow-sm border border-slate-100">
                <h4 className="font-semibold" style={{ color: BRAND.navy }}>{b.title}</h4>
                <p className="text-slate-600 mt-1 text-sm">{b.desc}</p>
              </div>
            ))}
          </div>
        </section>

        {/* Features */}
        <section id="features" className="max-w-6xl mx-auto px-6 pb-16">
          <h3 className="text-2xl font-semibold mb-4" style={{ color: BRAND.navy }}>Key Features</h3>
          <ul className="grid md:grid-cols-2 gap-3 text-slate-700">
            <li>Unified ingestion for instruments, ELNs, and LIMS with replayable pipelines.</li>
            <li>Schema registry + data contracts; versioned, provenance-rich records.</li>
            <li>QC dashboard, Batch Genealogy, DoE Explorer, and Bioreactor Ops apps.</li>
            <li>Audit trails, immutable storage, e-records, and e-signature readiness.</li>
            <li>AI/ML hooks for anomaly detection, soft sensors, and release risk scoring.</li>
          </ul>
        </section>
      </div>

      {/* Footer */}
      <footer className="border-t border-slate-200">
        <div className="max-w-6xl mx-auto px-6 py-8 grid gap-6 text-center">
          <div className="text-sm text-slate-600">
            © {new Date().getFullYear()} Brexa / tBrexa Bio — SDIaaS.io. All rights reserved.
          </div>
          <p className="text-slate-700 font-medium">tBrexa Bio’s SDIaaS is the regulatory-grade nervous system your data has been waiting for.</p>
        </div>
      </footer>
    </div>
  );
}
