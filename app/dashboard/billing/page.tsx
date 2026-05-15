"use client";

import { useState, useEffect, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import Link from "next/link";
import {
  CreditCard, Zap, Sparkles, Building2,
  CheckCircle2, AlertCircle, ArrowUpRight,
  Loader2, RefreshCw, Crown,
} from "lucide-react";
import { PLANS, PLAN_LIST, formatLimit, type PlanId } from "@/lib/plans";
import type { Subscription, UsageStats } from "@/lib/db/subscription.service";

// ─── Types ────────────────────────────────────────────────────────────────────

type BillingData = {
  subscription: Subscription | null;
  plan:         typeof PLANS.free;
  usage:        UsageStats;
  history:      Subscription[];
  isFreePlan:   boolean;
};

const PLAN_ICONS: Record<PlanId, React.ElementType> = {
  free:     Zap,
  pro:      Sparkles,
  business: Building2,
};

const PLAN_COLORS: Record<PlanId, string> = {
  free:     "zinc",
  pro:      "indigo",
  business: "purple",
};

const planBadge: Record<string, string> = {
  zinc:   "bg-zinc-800 text-zinc-300 border-zinc-700",
  indigo: "bg-indigo-600/20 text-indigo-300 border-indigo-500/30",
  purple: "bg-purple-600/20 text-purple-300 border-purple-500/30",
};

// ─── Usage bar ────────────────────────────────────────────────────────────────

function UsageBar({ label, used, limit }: { label: string; used: number; limit: number }) {
  const pct    = limit === -1 ? 0 : Math.min((used / limit) * 100, 100);
  const isOver = pct >= 90;

  return (
    <div>
      <div className="flex items-center justify-between mb-1.5">
        <span className="text-xs text-zinc-500">{label}</span>
        <span className={`text-xs font-medium ${isOver ? "text-amber-400" : "text-zinc-400"}`}>
          {used} / {formatLimit(limit)}
        </span>
      </div>
      <div className="h-1.5 bg-white/5 rounded-full overflow-hidden">
        {limit !== -1 && (
          <div
            className={`h-full rounded-full transition-all duration-500 ${
              isOver ? "bg-amber-500" : "bg-indigo-500"
            }`}
            style={{ width: `${pct}%` }}
          />
        )}
        {limit === -1 && (
          <div className="h-full w-full rounded-full bg-emerald-500/40" />
        )}
      </div>
    </div>
  );
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function BillingPage() {
  const searchParams = useSearchParams();
  const [data,         setData]         = useState<BillingData | null>(null);
  const [loading,      setLoading]      = useState(true);
  const [upgrading,    setUpgrading]    = useState<PlanId | null>(null);
  const [fetchError,   setFetchError]   = useState<string | null>(null);

  // Payment status from redirect
  const paymentStatus = searchParams.get("payment");
  const isMock        = searchParams.get("mock") === "true";

  const loadBilling = useCallback(async () => {
    setLoading(true);
    setFetchError(null);
    try {
      const res = await fetch("/api/subscription", { credentials: "include" });
      const json = await res.json();
      if (!res.ok) throw new Error(json.error);
      setData(json);
    } catch (e: unknown) {
      setFetchError(e instanceof Error ? e.message : "Failed to load billing info.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadBilling(); }, [loadBilling]);

  async function handleUpgrade(planId: PlanId) {
    if (planId === "free") return;
    setUpgrading(planId);
    try {
      const res = await fetch("/api/payment/sslcommerz", {
        method:      "POST",
        credentials: "include",
        headers:     { "Content-Type": "application/json" },
        body:        JSON.stringify({ plan_id: planId }),
      });
      const json = await res.json();
      if (json.paymentUrl) {
        window.location.href = json.paymentUrl;
      }
    } catch {
      alert("Payment failed to initialize. Please try again.");
    } finally {
      setUpgrading(null);
    }
  }

  const currentPlanId = (data?.plan?.id ?? "free") as PlanId;
  const Icon = PLAN_ICONS[currentPlanId];
  const color = PLAN_COLORS[currentPlanId];

  if (loading) {
    return (
      <div className="p-4 md:p-8 max-w-4xl animate-fade-in space-y-4">
        <div className="h-8 bg-white/5 rounded w-40 animate-pulse" />
        <div className="h-40 glass rounded-2xl animate-pulse" />
        <div className="h-32 glass rounded-2xl animate-pulse" />
      </div>
    );
  }

  return (
    <div className="p-4 md:p-8 max-w-4xl animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between mb-8 gap-4">
        <div>
          <p className="text-xs uppercase tracking-widest text-zinc-600 mb-1">Account</p>
          <h1 className="font-display text-3xl font-700 text-white">Billing & Plans</h1>
          <p className="text-zinc-500 text-sm mt-1">Manage your subscription and usage</p>
        </div>
        <button onClick={loadBilling} className="p-2.5 glass rounded-xl text-zinc-500 hover:text-zinc-300 border border-white/8 transition-all">
          <RefreshCw size={15} />
        </button>
      </div>

      {/* Payment status alerts */}
      {paymentStatus === "success" && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm">
          <CheckCircle2 size={16} />
          <span>
            {isMock
              ? "Mock payment successful! (Add SSLCommerz credentials for real payments)"
              : "Payment successful! Your plan has been upgraded."}
          </span>
        </div>
      )}
      {paymentStatus === "failed" && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
          <AlertCircle size={16} />
          <span>Payment failed. Please try again or contact support.</span>
        </div>
      )}
      {fetchError && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
          <AlertCircle size={16} /><span>{fetchError}</span>
        </div>
      )}

      <div className="space-y-5">
        {/* Current plan card */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-start justify-between mb-5 gap-4 flex-wrap">
            <div className="flex items-center gap-3">
              <div className={`p-3 rounded-xl border ${planBadge[color]}`}>
                <Icon size={18} />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h2 className="font-display text-lg font-700 text-white">
                    {data?.plan?.name ?? "Free"} Plan
                  </h2>
                  {currentPlanId !== "free" && (
                    <Crown size={14} className="text-amber-400" />
                  )}
                </div>
                <p className="text-zinc-500 text-sm">
                  {currentPlanId === "free"
                    ? "Free forever"
                    : `BDT ${data?.plan?.price?.toLocaleString()}/month`}
                </p>
              </div>
            </div>
            {data?.subscription?.current_period_end && (
              <div className="text-right">
                <p className="text-xs text-zinc-600">Renews on</p>
                <p className="text-sm text-zinc-300 font-medium">
                  {new Date(data.subscription.current_period_end).toLocaleDateString("en-US", {
                    month: "long", day: "numeric", year: "numeric",
                  })}
                </p>
              </div>
            )}
          </div>

          {/* Usage bars */}
          {data?.usage && data.plan && (
            <div className="space-y-3 p-4 bg-white/4 rounded-xl">
              <p className="text-xs font-semibold text-zinc-500 uppercase tracking-wider mb-3">
                Current Usage
              </p>
              <UsageBar label="Pages"  used={data.usage.pages} limit={data.plan.pages} />
              <UsageBar label="Leads"  used={data.usage.leads} limit={data.plan.leads} />
              <UsageBar
                label="AI Replies this month"
                used={data.usage.ai_replies}
                limit={data.plan.aiReplies}
              />
            </div>
          )}
        </div>

        {/* Upgrade options */}
        {currentPlanId !== "business" && (
          <div className="glass rounded-2xl p-6">
            <h2 className="font-display text-base font-700 text-white mb-1">
              Upgrade your plan
            </h2>
            <p className="text-zinc-500 text-sm mb-5">
              Get more pages, AI replies, and unlimited automation.
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {PLAN_LIST.filter(
                (p) =>
                  p.id !== "free" &&
                  p.id !== currentPlanId &&
                  (currentPlanId === "free" || p.id === "business")
              ).map((plan) => {
                const PlanIcon = PLAN_ICONS[plan.id];
                const planColor = PLAN_COLORS[plan.id];
                const isUpgrading = upgrading === plan.id;

                return (
                  <div
                    key={plan.id}
                    className={`p-4 rounded-xl border transition-all ${
                      plan.highlighted
                        ? "bg-indigo-600/10 border-indigo-500/30"
                        : "bg-white/4 border-white/8"
                    }`}
                  >
                    <div className="flex items-center gap-2.5 mb-3">
                      <div className={`p-2 rounded-lg border ${planBadge[planColor]}`}>
                        <PlanIcon size={14} />
                      </div>
                      <div>
                        <p className="font-semibold text-white text-sm">{plan.name}</p>
                        <p className="text-zinc-500 text-xs">BDT {plan.price.toLocaleString()}/mo</p>
                      </div>
                      {plan.badge && (
                        <span className="ml-auto text-[10px] font-bold px-2 py-0.5 bg-indigo-600 text-white rounded-full">
                          {plan.badge}
                        </span>
                      )}
                    </div>
                    <ul className="space-y-1.5 mb-4">
                      {plan.features.slice(0, 4).map((f) => (
                        <li key={f} className="flex items-center gap-2 text-xs text-zinc-400">
                          <CheckCircle2 size={11} className="text-emerald-400 flex-shrink-0" />
                          {f}
                        </li>
                      ))}
                    </ul>
                    <button
                      onClick={() => handleUpgrade(plan.id)}
                      disabled={!!upgrading}
                      className={`w-full py-2.5 text-xs font-semibold rounded-xl transition-all flex items-center justify-center gap-1.5 ${
                        plan.highlighted
                          ? "bg-indigo-600 hover:bg-indigo-500 text-white"
                          : "bg-purple-600 hover:bg-purple-500 text-white"
                      } disabled:opacity-50`}
                    >
                      {isUpgrading ? (
                        <><Loader2 size={12} className="animate-spin" /> Processing…</>
                      ) : (
                        <>Upgrade to {plan.name} <ArrowUpRight size={12} /></>
                      )}
                    </button>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Payment history */}
        {data?.history && data.history.length > 0 && (
          <div className="glass rounded-2xl p-6">
            <h2 className="font-display text-base font-700 text-white mb-4">
              Payment History
            </h2>
            <div className="space-y-2">
              {data.history.map((sub) => (
                <div
                  key={sub.id}
                  className="flex items-center justify-between py-3 border-b border-white/5 last:border-0"
                >
                  <div className="flex items-center gap-3">
                    <CreditCard size={14} className="text-zinc-600" />
                    <div>
                      <p className="text-sm font-medium text-white capitalize">
                        {sub.plan} Plan
                      </p>
                      <p className="text-xs text-zinc-600">
                        {new Date(sub.created_at).toLocaleDateString("en-US", {
                          month: "short", day: "numeric", year: "numeric",
                        })}
                        {sub.payment_method && (
                          <span className="ml-2 capitalize">· {sub.payment_method}</span>
                        )}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-semibold text-white">
                      BDT {sub.amount.toLocaleString()}
                    </p>
                    <span className={`text-[10px] font-medium px-2 py-0.5 rounded-full border capitalize ${
                      sub.status === "active"
                        ? "bg-emerald-500/15 text-emerald-400 border-emerald-500/25"
                        : "bg-zinc-800 text-zinc-500 border-zinc-700"
                    }`}>
                      {sub.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Payment methods info */}
        <div className="glass rounded-xl p-4 flex items-center gap-4 flex-wrap">
          <p className="text-xs text-zinc-600">Accepted payment methods:</p>
          {["bKash", "Nagad", "Rocket", "Visa", "Mastercard", "DBBL"].map((m) => (
            <span key={m} className="text-xs font-medium text-zinc-400 px-2.5 py-1 bg-white/5 rounded-lg border border-white/8">
              {m}
            </span>
          ))}
          <Link href="/pricing" className="ml-auto text-xs text-indigo-400 hover:text-indigo-300 flex items-center gap-1 transition-colors">
            View pricing <ArrowUpRight size={11} />
          </Link>
        </div>
      </div>
    </div>
  );
}