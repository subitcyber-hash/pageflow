import Link from "next/link";

export default function HomePage() {
  return (
    <main className="animated-gradient min-h-screen flex flex-col items-center justify-center relative overflow-hidden px-6">
      <div className="absolute top-[-20%] left-[-10%] w-[600px] h-[600px] bg-indigo-600/10 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-20%] right-[-10%] w-[500px] h-[500px] bg-purple-600/10 rounded-full blur-[120px] pointer-events-none" />
      <div
        className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage:
            "linear-gradient(rgba(255,255,255,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.5) 1px, transparent 1px)",
          backgroundSize: "60px 60px",
        }}
      />

      <nav className="absolute top-0 left-0 right-0 flex items-center justify-between px-5 md:px-8 py-4 md:py-5 z-10">
        <span className="font-display text-xl font-700 gradient-text">PageFlow</span>
        <div className="flex items-center gap-2 md:gap-4">
          <Link href="/pricing" className="hidden md:block text-sm text-zinc-400 hover:text-white transition-colors">
            Pricing
          </Link>
          <Link
            href="/auth"
            className="hidden md:block px-4 py-2 glass border border-white/10 hover:bg-white/8 text-zinc-300 text-sm font-semibold rounded-xl transition-all"
          >
            Sign in
          </Link>
          <Link
            href="/auth"
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold rounded-xl transition-all glow-sm whitespace-nowrap"
          >
            <span className="hidden md:inline">Get started free</span>
            <span className="md:hidden">Get started</span>
          </Link>
        </div>
      </nav>

      <div className="relative z-10 text-center max-w-3xl animate-fade-in pt-20 md:pt-0">
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full glass text-xs font-medium text-indigo-300 mb-8 tracking-wider uppercase border border-indigo-500/20">
          <span className="relative flex h-1.5 w-1.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-indigo-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-indigo-400" />
          </span>
          AI-powered - Bangla + English - Made for Bangladesh
        </div>

        <h1 className="font-display text-6xl md:text-7xl font-800 leading-[1.05] mb-6 tracking-tight">
          <span className="text-white">Automate your</span>
          <br />
          <span className="gradient-text">Facebook replies</span>
        </h1>

        <p className="text-zinc-400 text-lg md:text-xl leading-relaxed mb-10 max-w-xl mx-auto">
          Connect your page, set keyword rules, and let AI reply to customers automatically
          in Bangla or English. Save time, increase sales.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <Link
            href="/auth"
            className="px-8 py-3.5 bg-indigo-600 hover:bg-indigo-500 text-white font-semibold rounded-xl transition-all duration-200 glow-accent hover:glow-sm text-sm tracking-wide"
          >
            Start for free
          </Link>
          <Link
            href="/pricing"
            className="px-8 py-3.5 glass hover:bg-white/5 text-zinc-300 font-semibold rounded-xl transition-all duration-200 text-sm tracking-wide border border-white/8"
          >
            View pricing
          </Link>
        </div>

        <div className="mt-12 flex items-center justify-center gap-6 flex-wrap text-xs text-zinc-600">
          {[
            "Free plan available",
            "Bangla AI replies",
            "bKash and Nagad payment",
            "No credit card required",
          ].map((f) => (
            <span key={f} className="text-zinc-500">{"✓"} {f}</span>
          ))}
        </div>

        <div className="mt-12 flex items-center justify-center gap-10 text-center">
          {[
            { value: "BDT 799", label: "Pro plan/month" },
            { value: "99%",     label: "Uptime SLA"     },
            { value: "24/7",    label: "Auto replies"   },
          ].map((stat) => (
            <div key={stat.label}>
              <div className="font-display text-2xl font-700 text-white">{stat.value}</div>
              <div className="text-zinc-500 text-xs mt-0.5 uppercase tracking-widest">{stat.label}</div>
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}