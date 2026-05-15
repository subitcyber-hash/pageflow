"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Check, Sparkles, Zap, Building2, ArrowRight, Loader2 } from "lucide-react";
import { PLAN_LIST, type PlanId } from "@/lib/plans";

const PLAN_ICONS = {
  free:     Zap,
  pro:      Sparkles,
  business: Building2,
};

const PLAN_COLORS = {
  free:     "zinc",
  pro:      "indigo",
  business: "purple",
};

const iconBg: Record<string, string> = {
  zinc:   "bg-zinc-800 border-zinc-700 text-zinc-400",
  indigo: "bg-indigo-600/20 border-indigo-500/30 text-indigo-400",
  purple: "bg-purple-600/20 border-purple-500/30 text-purple-400",
};

const btnStyle: Record<string, string> = {
  zinc:   "bg-white/8 hover:bg-white/12 text-zinc-300 border border-white/10",
  indigo: "bg-indigo-600 hover:bg-indigo-500 text-white glow-sm",
  purple: "bg-purple-600 hover:bg-purple-500 text-white",
};

export default function PricingPage() {
  const router = useRouter();
  const [loadingPlan, setLoadingPlan] = useState<PlanId | null>(null);

  async function handleChoosePlan(planId: PlanId) {
    if (planId === "free") {
      router.push("/auth");
      return;
    }

    setLoadingPlan(planId);
    try {
      const res = await fetch("/api/payment/sslcommerz", {
        method:      "POST",
        credentials: "include",
        headers:     { "Content-Type": "application/json" },
        body:        JSON.stringify({ plan_id: planId }),
      });

      const data = await res.json();

      if (res.status === 401) {
        // Not logged in — go to auth first
        router.push(`/auth?next=/pricing&plan=${planId}`);
        return;
      }

      if (data.paymentUrl) {
        window.location.href = data.paymentUrl;
      }
    } catch {
      alert("Something went wrong. Please try again.");
    } finally {
      setLoadingPlan(null);
    }
  }

  return (
    <div className="animated-gradient min-h-screen relative overflow-hidden">
      {/* Orbs */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-indigo-600/10 rounded-full blur-[120px] pointer-events-none" />

      {/* Nav */}
      <nav className="relative z-10 flex items-center justify-between px-8 py-5 max-w-6xl mx-auto">
        <Link href="/" className="font-display text-xl font-700 gradient-text">
          PageFlow
        </Link>
        <div className="flex items-center gap-4">
          <Link href="/dashboard" className="text-sm text-zinc-400 hover:text-white transition-colors">
            Dashboard
          </Link>
          <Link
            href="/auth"
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold rounded-xl transition-all"
          >
            Get Started
          </Link>
        </div>
      </nav>

      {/* Hero */}
      <div className="relative z-10 text-center pt-16 pb-12 px-6">
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full glass text-xs font-medium text-indigo-300 mb-6 border border-indigo-500/20">
          <Sparkles size={12} />
          Simple, transparent pricing
        </div>
        <h1 className="font-display text-5xl md:text-6xl font-800 text-white mb-4 tracking-tight">
          Choose your plan
        </h1>
        <p className="text-zinc-400 text-lg max-w-xl mx-auto">
          Start free, upgrade when you need more. All plans include core automation features.
          Pay in BDT — no hidden fees.
        </p>
      </div>

      {/* Plans grid */}
      <div className="relative z-10 max-w-5xl mx-auto px-6 pb-20">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {PLAN_LIST.map((plan) => {
            const Icon  = PLAN_ICONS[plan.id];
            const color = PLAN_COLORS[plan.id];
            const isLoading = loadingPlan === plan.id;

            return (
              <div
                key={plan.id}
                className={`relative glass rounded-2xl p-6 flex flex-col transition-all duration-200 ${
                  plan.highlighted
                    ? "border border-indigo-500/40 shadow-xl shadow-indigo-500/10"
                    : "border border-white/6 hover:border-white/12"
                }`}
              >
                {/* Badge */}
                {plan.badge && (
                  <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 bg-indigo-600 text-white text-xs font-bold rounded-full whitespace-nowrap">
                    {plan.badge}
                  </div>
                )}

                {/* Icon + Name */}
                <div className={`w-10 h-10 rounded-xl border flex items-center justify-center mb-4 ${iconBg[color]}`}>
                  <Icon size={18} />
                </div>

                <h2 className="font-display text-xl font-700 text-white mb-1">{plan.name}</h2>

                {/* Price */}
                <div className="mb-5">
                  {plan.price === 0 ? (
                    <div className="font-display text-4xl font-800 text-white">Free</div>
                  ) : (
                    <div className="flex items-end gap-1">
                      <span className="text-zinc-500 text-sm mt-1">BDT</span>
                      <span className="font-display text-4xl font-800 text-white">
                        {plan.price.toLocaleString()}
                      </span>
                      <span className="text-zinc-500 text-sm mb-1">/month</span>
                    </div>
                  )}
                  {plan.price > 0 && (
                    <p className="text-zinc-600 text-xs mt-0.5">
                      ~${plan.priceUSD} USD
                    </p>
                  )}
                </div>

                {/* Limits */}
                <div className="grid grid-cols-2 gap-2 mb-5 p-3 bg-white/4 rounded-xl">
                  {[
                    { label: "Pages",       value: plan.pages       === -1 ? "Unlimited" : plan.pages },
                    { label: "Rules",       value: plan.automations === -1 ? "Unlimited" : plan.automations },
                    { label: "AI Replies",  value: plan.aiReplies   === 0  ? "None" : plan.aiReplies === -1 ? "Unlimited" : plan.aiReplies + "/mo" },
                    { label: "Leads",       value: plan.leads       === -1 ? "Unlimited" : plan.leads },
                  ].map(({ label, value }) => (
                    <div key={label} className="text-center">
                      <p className="font-display text-sm font-700 text-white">{value}</p>
                      <p className="text-[10px] text-zinc-600">{label}</p>
                    </div>
                  ))}
                </div>

                {/* Features */}
                <ul className="space-y-2.5 mb-6 flex-1">
                  {plan.features.map((feature) => (
                    <li key={feature} className="flex items-start gap-2.5 text-sm text-zinc-400">
                      <Check size={14} className="text-emerald-400 flex-shrink-0 mt-0.5" />
                      {feature}
                    </li>
                  ))}
                </ul>

                {/* CTA */}
                <button
                  onClick={() => handleChoosePlan(plan.id)}
                  disabled={isLoading}
                  className={`w-full py-3 rounded-xl text-sm font-semibold transition-all flex items-center justify-center gap-2 ${btnStyle[color]} disabled:opacity-50`}
                >
                  {isLoading ? (
                    <><Loader2 size={14} className="animate-spin" /> Processing…</>
                  ) : plan.price === 0 ? (
                    <>Get started free <ArrowRight size={14} /></>
                  ) : (
                    <>Subscribe now <ArrowRight size={14} /></>
                  )}
                </button>

                {plan.price > 0 && (
                  <p className="text-center text-zinc-700 text-[11px] mt-2.5">
                    Pay via bKash, Nagad, or Card
                  </p>
                )}
              </div>
            );
          })}
        </div>

        {/* FAQ / Trust */}
        <div className="mt-14 grid grid-cols-1 md:grid-cols-3 gap-5">
          {[
            { title: "Cancel anytime",    desc: "No contracts. Cancel your subscription at any time from the billing page." },
            { title: "Secure payments",   desc: "Payments processed via SSLCommerz. Supports bKash, Nagad, Rocket, and all cards." },
            { title: "Local support",     desc: "Bangla + English support. We understand your business needs." },
          ].map((item) => (
            <div key={item.title} className="glass rounded-xl p-4 border border-white/5">
              <p className="font-semibold text-white text-sm mb-1">{item.title}</p>
              <p className="text-zinc-500 text-xs leading-relaxed">{item.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}