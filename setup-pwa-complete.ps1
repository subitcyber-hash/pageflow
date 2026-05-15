# PWA Complete setup - all files
$OutputEncoding = [System.Text.Encoding]::UTF8

New-Item -ItemType Directory -Force -Path ".\app" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard\ai-settings" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard\automation" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard\billing" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard\leads" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard\pages" | Out-Null
New-Item -ItemType Directory -Force -Path ".\components" | Out-Null

@'
import { createServerSupabaseClient } from "@/lib/supabase-server";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS } from "@/lib/plans";
import { TrendingUp, Users, MessageSquare, Zap, ArrowUpRight, Crown } from "lucide-react";
import Link from "next/link";

const colorMap: Record<string, string> = {
  indigo:  "bg-indigo-600/15 text-indigo-300 border-indigo-500/20",
  purple:  "bg-purple-600/15 text-purple-300 border-purple-500/20",
  sky:     "bg-sky-600/15 text-sky-300 border-sky-500/20",
  emerald: "bg-emerald-600/15 text-emerald-300 border-emerald-500/20",
};

export default async function DashboardPage() {
  const supabase = await createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();

  const displayName = user?.email?.split("@")[0] ?? "there";

  // Load real stats in parallel
  const [
    pagesRes,
    leadsRes,
    automationsRes,
    subRes,
  ] = await Promise.all([
    supabase.from("pages").select("id", { count: "exact", head: true }).eq("user_id", user?.id ?? ""),
    supabase.from("leads").select("id", { count: "exact", head: true }).in(
      "page_id",
      (await supabase.from("pages").select("id").eq("user_id", user?.id ?? "")).data?.map((p: { id: string }) => p.id) ?? []
    ),
    supabase.from("automations").select("id,enabled", { count: "exact" }).in(
      "page_id",
      (await supabase.from("pages").select("id").eq("user_id", user?.id ?? "")).data?.map((p: { id: string }) => p.id) ?? []
    ),
    user ? SubscriptionService.get(supabase, user.id) : Promise.resolve({ data: null, error: null }),
  ]);

  const totalPages      = pagesRes.count       ?? 0;
  const totalLeads      = leadsRes.count        ?? 0;
  const totalAutos      = automationsRes.count  ?? 0;
  const activeAutos     = automationsRes.data?.filter((a: { enabled: boolean }) => a.enabled).length ?? 0;

  const currentPlan     = subRes.data?.plan ?? "free";
  const planDetails     = PLANS[currentPlan];

  const stats = [
    { label: "Connected Pages",    value: totalPages.toString(),   change: `of ${planDetails.pages === -1 ? "Unlimited" : planDetails.pages} allowed`,  icon: TrendingUp,    color: "indigo" },
    { label: "Total Leads",        value: totalLeads.toString(),   change: "Captured from messages",  icon: Users,         color: "purple" },
    { label: "Active Automations", value: activeAutos.toString(),  change: `${totalAutos} rules total`,               icon: Zap,           color: "sky"    },
    { label: "AI Replies",         value: planDetails.aiReplies === 0 ? "None" : planDetails.aiReplies === -1 ? "Unlimited" : `${planDetails.aiReplies}/mo`, change: currentPlan === "free" ? "Upgrade to enable" : "Monthly limit", icon: MessageSquare, color: "emerald" },
  ];

  return (
    <div className="p-4 md:p-8 max-w-6xl animate-fade-in">
      {/* Header */}
      <div className="mb-8 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <p className="text-xs uppercase tracking-widest text-zinc-600 mb-1">Overview</p>
          <h1 className="font-display text-3xl font-700 text-white">
            Welcome back, <span className="gradient-text capitalize">{displayName}</span> 👋
          </h1>
          <p className="text-zinc-500 text-sm mt-1.5">
            Here&apos;s what&apos;s happening across your pages today.
          </p>
        </div>

        {/* Plan badge */}
        <Link
          href="/dashboard/billing"
          className="flex items-center gap-2 px-4 py-2 glass rounded-xl border border-white/8 hover:border-indigo-500/30 transition-all group"
        >
          <Crown size={14} className={currentPlan === "free" ? "text-zinc-500" : "text-amber-400"} />
          <span className="text-sm font-semibold text-zinc-300 capitalize group-hover:text-white transition-colors">
            {planDetails.name} Plan
          </span>
          {currentPlan === "free" && (
            <span className="text-[10px] font-bold px-2 py-0.5 bg-indigo-600 text-white rounded-full">
              Upgrade
            </span>
          )}
        </Link>
      </div>

      {/* Free plan upgrade banner */}
      {currentPlan === "free" && (
        <div className="mb-7 p-4 rounded-xl bg-indigo-600/10 border border-indigo-500/20 flex items-center justify-between gap-4 flex-wrap">
          <div>
            <p className="text-sm font-semibold text-indigo-300">
              You&apos;re on the Free plan
            </p>
            <p className="text-xs text-zinc-500 mt-0.5">
              Upgrade to Pro for AI replies, more pages, and unlimited automation.
            </p>
          </div>
          <Link
            href="/dashboard/billing"
            className="flex items-center gap-1.5 px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold rounded-xl transition-all glow-sm whitespace-nowrap"
          >
            Upgrade now <ArrowUpRight size={12} />
          </Link>
        </div>
      )}

      {/* Stats grid */}
      <div className="grid grid-cols-2 xl:grid-cols-4 gap-4 mb-10">
        {stats.map(({ label, value, change, icon: Icon, color }) => (
          <div key={label} className="glass rounded-2xl p-5 flex flex-col gap-4 hover:bg-white/4 transition-colors">
            <div className="flex items-start justify-between">
              <div className={`p-2.5 rounded-xl border ${colorMap[color]}`}>
                <Icon size={16} />
              </div>
              <ArrowUpRight size={14} className="text-zinc-700" />
            </div>
            <div>
              <p className="font-display text-3xl font-700 text-white">{value}</p>
              <p className="text-zinc-500 text-xs mt-0.5">{label}</p>
            </div>
            <div className={`text-xs font-medium px-2 py-1 rounded-lg inline-block w-fit border ${colorMap[color]}`}>
              {change}
            </div>
          </div>
        ))}
      </div>

      {/* Bottom grid */}
      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* Quick actions */}
        <div className="lg:col-span-2 glass rounded-2xl p-6 flex flex-col gap-4">
          <h2 className="font-display text-base font-700 text-white">Quick Actions</h2>
          {[
            { label: "Connect a Page",    href: "/dashboard/pages",       emoji: "📄" },
            { label: "Create Automation", href: "/dashboard/automation",  emoji: "⚡" },
            { label: "Configure AI",      href: "/dashboard/ai-settings", emoji: "🧠" },
            { label: "View Leads",        href: "/dashboard/leads",       emoji: "👥" },
            { label: "Manage Billing",    href: "/dashboard/billing",     emoji: "💳" },
          ].map((action) => (
            <Link
              key={action.href}
              href={action.href}
              className="flex items-center gap-3.5 p-3.5 rounded-xl bg-white/4 hover:bg-white/7 border border-white/5 hover:border-indigo-500/30 transition-all duration-150 group"
            >
              <span className="text-lg">{action.emoji}</span>
              <span className="text-sm font-medium text-zinc-300 group-hover:text-white transition-colors">
                {action.label}
              </span>
              <ArrowUpRight size={13} className="ml-auto text-zinc-700 group-hover:text-indigo-400 transition-colors" />
            </Link>
          ))}
        </div>

        {/* Plan details */}
        <div className="lg:col-span-3 glass rounded-2xl p-6">
          <div className="flex items-center justify-between mb-5">
            <h2 className="font-display text-base font-700 text-white">Plan Details</h2>
            <Link
              href="/pricing"
              className="text-xs text-indigo-400 hover:text-indigo-300 flex items-center gap-1 transition-colors"
            >
              View all plans <ArrowUpRight size={11} />
            </Link>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {[
              { label: "Pages allowed",       value: planDetails.pages       === -1 ? "Unlimited" : planDetails.pages       },
              { label: "Automation rules",     value: planDetails.automations === -1 ? "Unlimited" : planDetails.automations },
              { label: "AI replies/month",     value: planDetails.aiReplies   === 0  ? "None"      : planDetails.aiReplies   === -1 ? "Unlimited" : planDetails.aiReplies },
              { label: "Leads storage",        value: planDetails.leads       === -1 ? "Unlimited" : planDetails.leads       },
            ].map(({ label, value }) => (
              <div key={label} className="p-3 bg-white/4 rounded-xl">
                <p className="font-display text-lg font-700 text-white">{value}</p>
                <p className="text-xs text-zinc-600 mt-0.5">{label}</p>
              </div>
            ))}
          </div>

          {currentPlan !== "business" && (
            <Link
              href="/dashboard/billing"
              className="mt-4 flex items-center justify-center gap-2 w-full py-2.5 bg-indigo-600/15 hover:bg-indigo-600/25 border border-indigo-500/20 text-indigo-300 text-sm font-semibold rounded-xl transition-all"
            >
              <Crown size={14} />
              Upgrade your plan
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}

'@ | Set-Content -Path '.\app\dashboard\page.tsx' -Encoding UTF8

@'
"use client";

import { useState, useEffect, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import {
  Plus, Search, Globe, Users, MessageCircle,
  MoreVertical, TrendingUp, CheckCircle2,
  RefreshCw, Loader2, Unlink, AlertCircle,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Page = {
  id:               string;
  name:             string;
  category:         string;
  followers:        number;
  status:           string;
  facebook_page_id: string | null;
  access_token:     string | null;
  created_at:       string;
};

const COLORS = ["indigo", "sky", "amber", "emerald", "purple", "rose"];

const avatarColors: Record<string, string> = {
  indigo:  "from-indigo-600 to-indigo-800",
  sky:     "from-sky-500 to-sky-700",
  amber:   "from-amber-500 to-amber-700",
  emerald: "from-emerald-500 to-emerald-700",
  purple:  "from-purple-500 to-purple-700",
  rose:    "from-rose-500 to-rose-700",
};

const statusStyles: Record<string, string> = {
  active:       "bg-emerald-500/15 text-emerald-400 border-emerald-500/25",
  paused:       "bg-amber-500/15 text-amber-400 border-amber-500/25",
  disconnected: "bg-zinc-800 text-zinc-500 border-zinc-700",
};

function makeAvatar(name: string) {
  return name.split(" ").map((w) => w[0]).join("").toUpperCase().slice(0, 2);
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function PagesPage() {
  const searchParams = useSearchParams();

  const [search,      setSearch]      = useState("");
  const [pages,       setPages]       = useState<Page[]>([]);
  const [loading,     setLoading]     = useState(true);
  const [fetchError,  setFetchError]  = useState<string | null>(null);
  const [notification, setNotification] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [disconnectingId, setDisconnectingId] = useState<string | null>(null);

  // Handle redirect from Facebook OAuth callback
  useEffect(() => {
    const connected = searchParams.get("fb_connected");
    const fbError   = searchParams.get("fb_error");

    if (connected) {
      setNotification({
        type:    "success",
        message: `${connected} Facebook page${Number(connected) > 1 ? "s" : ""} connected successfully!`,
      });
    } else if (fbError) {
      const messages: Record<string, string> = {
        denied:        "Facebook permission denied. Please try again and accept all permissions.",
        token_failed:  "Failed to get Facebook access token. Please try again.",
        pages_failed:  "Could not load your Facebook pages. Make sure you have admin access.",
        no_pages:      "No Facebook pages found. Create a page on Facebook first.",
        server_error:  "Server error during connection. Please try again.",
        missing_params: "Invalid callback parameters. Please try again.",
      };
      setNotification({
        type:    "error",
        message: messages[fbError] ?? "Facebook connection failed. Please try again.",
      });
    }

    // Clear URL params
    if (connected || fbError) {
      window.history.replaceState({}, "", "/dashboard/pages");
    }
  }, [searchParams]);

  const loadPages = useCallback(async () => {
    setLoading(true);
    setFetchError(null);
    try {
      const res  = await fetch("/api/pages", { credentials: "include" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setPages(data.pages ?? []);
    } catch (e: unknown) {
      setFetchError(e instanceof Error ? e.message : "Failed to load pages.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadPages(); }, [loadPages]);

  // Auto-dismiss notification
  useEffect(() => {
    if (!notification) return;
    const t = setTimeout(() => setNotification(null), 5000);
    return () => clearTimeout(t);
  }, [notification]);

  function handleConnectWithFacebook() {
    // Redirect to our OAuth initiation route
    window.location.href = "/api/facebook/connect";
  }

  async function handleDisconnect(pageId: string, pageName: string) {
    if (!confirm(`Disconnect "${pageName}"? Automation will stop for this page.`)) return;

    setDisconnectingId(pageId);
    try {
      const res  = await fetch("/api/facebook/disconnect", {
        method:      "POST",
        credentials: "include",
        headers:     { "Content-Type": "application/json" },
        body:        JSON.stringify({ page_id: pageId }),
      });
      const data = await res.json();

      if (res.ok) {
        setNotification({ type: "success", message: data.message });
        await loadPages();
      } else {
        setNotification({ type: "error", message: data.error ?? "Failed to disconnect." });
      }
    } finally {
      setDisconnectingId(null);
    }
  }

  const filtered = pages.filter((p) =>
    p.name.toLowerCase().includes(search.toLowerCase()) ||
    (p.category ?? "").toLowerCase().includes(search.toLowerCase())
  );

  const activeCount = pages.filter((p) => p.status === "active").length;
  const hasFbCreds  = true; // always show connect button — API handles missing creds

  return (
    <div className="p-4 md:p-8 max-w-6xl animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between mb-8 gap-4 flex-wrap">
        <div>
          <p className="text-xs uppercase tracking-widest text-zinc-600 mb-1">Management</p>
          <h1 className="font-display text-3xl font-700 text-white">Facebook Pages</h1>
          <p className="text-zinc-500 text-sm mt-1">
            {loading ? "Loading..." : `${pages.length} pages connected - ${activeCount} active`}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={loadPages}
            disabled={loading}
            className="p-2.5 glass rounded-xl text-zinc-500 hover:text-zinc-300 border border-white/8 transition-all disabled:opacity-40"
          >
            <RefreshCw size={15} className={loading ? "animate-spin" : ""} />
          </button>
          <button
            onClick={handleConnectWithFacebook}
            className="flex items-center gap-2 px-5 py-2.5 bg-[#1877F2] hover:bg-[#166fe5] text-white text-sm font-semibold rounded-xl transition-all glow-sm"
          >
            <Plus size={16} />
            Connect Facebook Page
          </button>
        </div>
      </div>

      {/* Notification banner */}
      {notification && (
        <div className={`mb-5 flex items-center gap-3 px-4 py-3 rounded-xl text-sm border ${
          notification.type === "success"
            ? "bg-emerald-500/10 border-emerald-500/20 text-emerald-400"
            : "bg-red-500/10 border-red-500/20 text-red-400"
        }`}>
          {notification.type === "success"
            ? <CheckCircle2 size={15} />
            : <AlertCircle size={15} />
          }
          <span>{notification.message}</span>
        </div>
      )}

      {/* Error */}
      {fetchError && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-400 text-sm">
          <span>⚠</span><span>{fetchError}</span>
        </div>
      )}

      {/* How it works info bar */}
      {pages.length === 0 && !loading && (
        <div className="mb-6 p-5 glass rounded-2xl border border-indigo-500/15 bg-indigo-600/5">
          <h3 className="font-semibold text-white text-sm mb-3">How to connect your Facebook Page</h3>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {[
              { step: "1", title: "Click Connect",     desc: "Click the blue button to start Facebook OAuth" },
              { step: "2", title: "Grant Permission",  desc: "Select your page and accept the required permissions" },
              { step: "3", title: "Auto-reply starts", desc: "Your automation rules and AI start working instantly" },
            ].map((s) => (
              <div key={s.step} className="flex items-start gap-3">
                <div className="w-6 h-6 rounded-full bg-indigo-600 flex items-center justify-center text-xs font-bold text-white flex-shrink-0">
                  {s.step}
                </div>
                <div>
                  <p className="text-xs font-semibold text-zinc-300">{s.title}</p>
                  <p className="text-xs text-zinc-600 mt-0.5">{s.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Search */}
      {pages.length > 0 && (
        <div className="flex items-center gap-3 mb-6">
          <div className="relative flex-1 max-w-sm">
            <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600" />
            <input
              type="text"
              placeholder="Search pages..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 bg-white/5 border border-white/8 rounded-xl text-sm text-zinc-300 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/40 transition-all"
            />
          </div>
          <div className="flex items-center gap-2">
            {["All", "Active", "Paused"].map((f) => (
              <button key={f} className="px-3.5 py-2 text-xs font-medium rounded-lg glass text-zinc-400 hover:text-zinc-200 hover:bg-white/6 transition-all">
                {f}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Loading skeleton */}
      {loading && (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="glass rounded-2xl p-5 animate-pulse flex flex-col gap-4">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-xl bg-white/8" />
                <div className="flex-1 space-y-2">
                  <div className="h-3 bg-white/8 rounded-lg w-2/3" />
                  <div className="h-2.5 bg-white/5 rounded-lg w-1/3" />
                </div>
              </div>
              <div className="grid grid-cols-3 gap-2">
                {[...Array(3)].map((_, j) => <div key={j} className="h-14 bg-white/5 rounded-xl" />)}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Pages grid */}
      {!loading && (
        <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4">
          {filtered.map((page, idx) => {
            const color         = COLORS[idx % COLORS.length];
            const isDisconnecting = disconnectingId === page.id;
            const isReal        = !!page.facebook_page_id;

            return (
              <div
                key={page.id}
                className={`glass rounded-2xl p-5 flex flex-col gap-4 transition-all duration-200 group ${
                  page.status === "active" ? "hover:bg-white/4" : "opacity-60 hover:opacity-80"
                }`}
              >
                {/* Top row */}
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className={`w-11 h-11 rounded-xl bg-gradient-to-br ${avatarColors[color]} flex items-center justify-center text-sm font-bold text-white font-display shadow-lg`}>
                      {makeAvatar(page.name)}
                    </div>
                    <div>
                      <p className="font-semibold text-white text-sm leading-tight">{page.name}</p>
                      <p className="text-zinc-600 text-xs mt-0.5">{page.category ?? "Business"}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`text-[11px] font-medium px-2 py-0.5 rounded-full border ${statusStyles[page.status] ?? statusStyles.active} capitalize`}>
                      {page.status}
                    </span>
                    {page.status === "active" && (
                      <button
                        onClick={() => handleDisconnect(page.id, page.name)}
                        disabled={isDisconnecting}
                        className="p-1 rounded-lg text-zinc-700 hover:text-red-400 hover:bg-red-500/10 transition-colors opacity-0 group-hover:opacity-100 disabled:opacity-40"
                        title="Disconnect page"
                      >
                        {isDisconnecting
                          ? <Loader2 size={13} className="animate-spin" />
                          : <Unlink size={13} />
                        }
                      </button>
                    )}
                  </div>
                </div>

                {/* Stats row */}
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { icon: Users,         value: page.followers >= 1000 ? `${(page.followers/1000).toFixed(1)}K` : page.followers, label: "Followers" },
                    { icon: MessageCircle, value: isReal ? "Live"  : "Mock",     label: "Messages"  },
                    { icon: TrendingUp,    value: isReal ? "Real"  : "Demo",     label: "Source"    },
                  ].map(({ icon: Icon, value, label }) => (
                    <div key={label} className="bg-white/4 rounded-xl p-2.5 text-center">
                      <Icon size={12} className="mx-auto mb-1 text-zinc-600" />
                      <p className="text-xs font-semibold text-zinc-300">{value}</p>
                      <p className="text-[10px] text-zinc-600">{label}</p>
                    </div>
                  ))}
                </div>

                {/* Footer */}
                <div className="flex items-center justify-between pt-2 border-t border-white/5">
                  <div className="flex items-center gap-1.5 text-xs text-zinc-600">
                    <Globe size={11} />
                    <span>
                      {page.facebook_page_id
                        ? `fb.com/${page.facebook_page_id}`
                        : "facebook.com/..."}
                    </span>
                  </div>
                  {page.status === "active" && (
                    <div className="flex items-center gap-1 text-xs text-emerald-500">
                      <CheckCircle2 size={11} />
                      <span>{isReal ? "Webhook active" : "AI active"}</span>
                    </div>
                  )}
                </div>
              </div>
            );
          })}

          {/* Empty state */}
          {filtered.length === 0 && pages.length > 0 && (
            <div className="col-span-full text-center py-12 text-zinc-600 text-sm">
              No pages match your search.
            </div>
          )}

          {/* Add CTA card */}
          <button
            onClick={handleConnectWithFacebook}
            className="glass rounded-2xl p-5 border-2 border-dashed border-white/8 hover:border-[#1877F2]/40 hover:bg-[#1877F2]/5 transition-all duration-200 flex flex-col items-center justify-center gap-3 min-h-[200px] group"
          >
            <div className="w-10 h-10 rounded-xl bg-white/5 group-hover:bg-[#1877F2]/20 flex items-center justify-center transition-colors">
              <Plus size={18} className="text-zinc-600 group-hover:text-[#1877F2] transition-colors" />
            </div>
            <div className="text-center">
              <p className="text-sm font-semibold text-zinc-500 group-hover:text-zinc-300 transition-colors">
                Connect another page
              </p>
              <p className="text-xs text-zinc-700 mt-0.5">Via Facebook OAuth</p>
            </div>
          </button>
        </div>
      )}
    </div>
  );
}

'@ | Set-Content -Path '.\app\dashboard\pages\page.tsx' -Encoding UTF8

@'
"use client";

import { useState, useEffect, useCallback } from "react";
import {
  Plus, Zap, ToggleLeft, ToggleRight, Pencil,
  Trash2, Loader2, RefreshCw, X, ChevronDown,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Page = { id: string; name: string; status: string };

type Automation = {
  id: string;
  page_id: string;
  trigger: string;
  reply: string;
  enabled: boolean;
  created_at: string;
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

const COLORS = ["indigo", "emerald", "sky", "purple", "amber", "rose"];
const colorBadge: Record<string, string> = {
  indigo:  "bg-indigo-600/15 text-indigo-300 border-indigo-500/20",
  emerald: "bg-emerald-600/15 text-emerald-300 border-emerald-500/20",
  sky:     "bg-sky-600/15 text-sky-300 border-sky-500/20",
  purple:  "bg-purple-600/15 text-purple-300 border-purple-500/20",
  amber:   "bg-amber-600/15 text-amber-300 border-amber-500/20",
  rose:    "bg-rose-600/15 text-rose-300 border-rose-500/20",
};

// ─── Modal ────────────────────────────────────────────────────────────────────

type ModalProps = {
  pages: Page[];
  editItem: Automation | null;
  selectedPageId: string;
  onClose: () => void;
  onSaved: () => void;
};

function AutomationModal({ pages, editItem, selectedPageId, onClose, onSaved }: ModalProps) {
  const [pageId,  setPageId]  = useState(editItem?.page_id  ?? selectedPageId ?? pages[0]?.id ?? "");
  const [trigger, setTrigger] = useState(editItem?.trigger  ?? "");
  const [reply,   setReply]   = useState(editItem?.reply    ?? "");
  const [saving,  setSaving]  = useState(false);
  const [error,   setError]   = useState<string | null>(null);

  async function handleSave() {
    if (!pageId)        return setError("Please select a page.");
    if (!trigger.trim()) return setError("Trigger keyword is required.");
    if (!reply.trim())   return setError("Reply message is required.");

    setSaving(true);
    setError(null);

    try {
      let res: Response;

      if (editItem) {
        res = await fetch(`/api/automation/${editItem.id}`, {
          method: "PATCH",
          credentials: "include",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ trigger: trigger.trim(), reply: reply.trim() }),
        });
      } else {
        res = await fetch("/api/automation", {
          method: "POST",
          credentials: "include",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ page_id: pageId, trigger: trigger.trim(), reply: reply.trim() }),
        });
      }

      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "Failed to save automation.");
      } else {
        onSaved();
        onClose();
      }
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
      <div
        className="relative z-10 glass rounded-2xl p-7 max-w-lg w-full animate-slide-up"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="font-display text-lg font-700 text-white">
              {editItem ? "Edit Automation" : "New Automation Rule"}
            </h2>
            <p className="text-xs text-zinc-500 mt-0.5">
              {editItem ? "Update keyword and reply" : "Set a keyword trigger and automatic reply"}
            </p>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg text-zinc-600 hover:text-zinc-300 hover:bg-white/8 transition-all">
            <X size={16} />
          </button>
        </div>

        <div className="space-y-4">
          {/* Page selector */}
          {!editItem && (
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                Facebook Page
              </label>
              <div className="relative">
                <select
                  value={pageId}
                  onChange={(e) => setPageId(e.target.value)}
                  className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-300 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/40 transition-all appearance-none"
                >
                  <option value="" disabled>Select a page…</option>
                  {pages.map((p) => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
                <ChevronDown size={14} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-zinc-600 pointer-events-none" />
              </div>
            </div>
          )}

          {/* Trigger */}
          <div>
            <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
              Trigger Keyword
            </label>
            <input
              type="text"
              value={trigger}
              onChange={(e) => setTrigger(e.target.value)}
              placeholder=''e.g. price, দাম, how much, shipping''
              className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all"
            />
            <p className="text-[11px] text-zinc-700 mt-1.5">
              When a message contains this word → auto-reply is sent
            </p>
          </div>

          {/* Reply */}
          <div>
            <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
              Auto Reply Message
            </label>
            <textarea
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              placeholder={''e.g. আমাদের পণ্যের দাম ৫০০৳ থেকে শুরু। বিস্তারিত জানতে inbox করুন! 😊''}
              rows={4}
              className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all resize-none"
            />
            <div className="flex items-center justify-between mt-1.5">
              <p className="text-[11px] text-zinc-700">Supports Bangla + English</p>
              <p className={`text-[11px] ${reply.length > 1800 ? "text-amber-400" : "text-zinc-700"}`}>
                {reply.length}/2000
              </p>
            </div>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-start gap-2.5 p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              <span className="flex-shrink-0">⚠</span>
              <span>{error}</span>
            </div>
          )}

          {/* Actions */}
          <div className="flex items-center gap-3 pt-1">
            <button
              onClick={onClose}
              className="flex-1 py-2.5 glass border border-white/8 text-zinc-400 hover:text-zinc-200 text-sm font-medium rounded-xl transition-all"
            >
              Cancel
            </button>
            <button
              onClick={handleSave}
              disabled={saving}
              className="flex-1 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-sm font-semibold rounded-xl transition-all flex items-center justify-center gap-2"
            >
              {saving ? (
                <><Loader2 size={14} className="animate-spin" /> Saving…</>
              ) : editItem ? "Update Rule" : "Create Rule"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function AutomationPage() {
  const [pages,          setPages]          = useState<Page[]>([]);
  const [automations,    setAutomations]    = useState<Automation[]>([]);
  const [selectedPageId, setSelectedPageId] = useState<string>("");
  const [loading,        setLoading]        = useState(true);
  const [togglingId,     setTogglingId]     = useState<string | null>(null);
  const [deletingId,     setDeletingId]     = useState<string | null>(null);
  const [showModal,      setShowModal]      = useState(false);
  const [editItem,       setEditItem]       = useState<Automation | null>(null);
  const [fetchError,     setFetchError]     = useState<string | null>(null);

  // Load pages first
  useEffect(() => {
    fetch("/api/pages", { credentials: "include" })
      .then((r) => r.json())
      .then((d) => {
        const list: Page[] = d.pages ?? [];
        setPages(list);
        if (list.length > 0) setSelectedPageId(list[0].id);
      })
      .catch(() => setFetchError("Could not load pages."));
  }, []);

  // Load automations whenever selected page changes
  const loadAutomations = useCallback(async () => {
    if (!selectedPageId) return;
    setLoading(true);
    setFetchError(null);
    try {
      const res = await fetch(`/api/automation?page_id=${selectedPageId}`, {
        credentials: "include",
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setAutomations(data.automations ?? []);
    } catch (e: unknown) {
      setFetchError(e instanceof Error ? e.message : "Failed to load automations.");
    } finally {
      setLoading(false);
    }
  }, [selectedPageId]);

  useEffect(() => { loadAutomations(); }, [loadAutomations]);

  // Toggle enable/disable
  async function handleToggle(automation: Automation) {
    setTogglingId(automation.id);
    try {
      const res = await fetch(`/api/automation/${automation.id}`, {
        method: "PATCH",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ enabled: !automation.enabled }),
      });
      if (res.ok) {
        setAutomations((prev) =>
          prev.map((a) => a.id === automation.id ? { ...a, enabled: !a.enabled } : a)
        );
      }
    } finally {
      setTogglingId(null);
    }
  }

  // Delete
  async function handleDelete(id: string) {
    if (!confirm("Delete this automation rule?")) return;
    setDeletingId(id);
    try {
      const res = await fetch(`/api/automation/${id}`, {
        method: "DELETE",
        credentials: "include",
      });
      if (res.ok) {
        setAutomations((prev) => prev.filter((a) => a.id !== id));
      }
    } finally {
      setDeletingId(null);
    }
  }

  function openCreate() { setEditItem(null); setShowModal(true); }
  function openEdit(a: Automation) { setEditItem(a); setShowModal(true); }
  function closeModal() { setShowModal(false); setEditItem(null); }

  const selectedPage = pages.find((p) => p.id === selectedPageId);
  const activeCount  = automations.filter((a) => a.enabled).length;

  return (
    <div className="p-4 md:p-8 max-w-5xl animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between mb-8 gap-4 flex-wrap">
        <div>
          <p className="text-xs uppercase tracking-widest text-zinc-600 mb-1">Workflows</p>
          <h1 className="font-display text-3xl font-700 text-white">Automation Rules</h1>
          <p className="text-zinc-500 text-sm mt-1">
            {loading ? "Loading…" : `${activeCount} of ${automations.length} rules active`}
            {selectedPage && (
              <span className="ml-2 text-indigo-400">· {selectedPage.name}</span>
            )}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={loadAutomations}
            disabled={loading}
            className="p-2.5 glass rounded-xl text-zinc-500 hover:text-zinc-300 border border-white/8 transition-all disabled:opacity-40"
          >
            <RefreshCw size={15} className={loading ? "animate-spin" : ""} />
          </button>
          <button
            onClick={openCreate}
            disabled={pages.length === 0}
            className="flex items-center gap-2 px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-40 text-white text-sm font-semibold rounded-xl transition-all glow-sm"
          >
            <Plus size={16} />
            New Rule
          </button>
        </div>
      </div>

      {/* Page selector tabs */}
      {pages.length > 0 && (
        <div className="flex items-center gap-2 mb-6 flex-wrap">
          <span className="text-xs text-zinc-600 uppercase tracking-wider mr-1">Page:</span>
          {pages.map((p) => (
            <button
              key={p.id}
              onClick={() => setSelectedPageId(p.id)}
              className={`px-3.5 py-1.5 text-xs font-semibold rounded-lg transition-all border ${
                selectedPageId === p.id
                  ? "bg-indigo-600 border-indigo-500 text-white"
                  : "glass border-white/8 text-zinc-400 hover:text-zinc-200"
              }`}
            >
              {p.name}
            </button>
          ))}
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 mb-7">
        {[
          { label: "Total Rules",  value: automations.length },
          { label: "Active",       value: activeCount },
          { label: "Paused",       value: automations.length - activeCount },
        ].map(({ label, value }) => (
          <div key={label} className="glass rounded-xl px-5 py-4 text-center">
            <p className="font-display text-2xl font-700 text-white">{value}</p>
            <p className="text-xs text-zinc-600 mt-0.5">{label}</p>
          </div>
        ))}
      </div>

      {/* Error */}
      {fetchError && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
          <span>⚠</span><span>{fetchError}</span>
        </div>
      )}

      {/* Loading skeleton */}
      {loading && (
        <div className="space-y-3">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="glass rounded-2xl p-5 animate-pulse flex items-center gap-5">
              <div className="w-11 h-11 rounded-xl bg-white/8 flex-shrink-0" />
              <div className="flex-1 space-y-2">
                <div className="h-3 bg-white/8 rounded-lg w-1/3" />
                <div className="h-2.5 bg-white/5 rounded-lg w-2/3" />
              </div>
              <div className="w-10 h-6 bg-white/5 rounded-full" />
            </div>
          ))}
        </div>
      )}

      {/* Automation list */}
      {!loading && (
        <div className="space-y-3">
          {automations.length === 0 ? (
            /* Empty state */
            <div className="glass rounded-2xl p-12 text-center">
              <div className="w-14 h-14 rounded-2xl bg-indigo-600/15 border border-indigo-500/20 flex items-center justify-center mx-auto mb-4">
                <Zap size={22} className="text-indigo-400" />
              </div>
              <h3 className="font-display text-lg font-700 text-white mb-2">No rules yet</h3>
              <p className="text-zinc-500 text-sm mb-5 max-w-sm mx-auto">
                Create your first automation rule. When a customer sends a keyword, your page replies instantly.
              </p>
              <button
                onClick={openCreate}
                disabled={pages.length === 0}
                className="inline-flex items-center gap-2 px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold rounded-xl transition-all glow-sm"
              >
                <Plus size={15} />
                Create First Rule
              </button>
              {pages.length === 0 && (
                <p className="text-zinc-600 text-xs mt-3">Connect a Facebook page first</p>
              )}
            </div>
          ) : (
            automations.map((auto, i) => {
              const color = COLORS[i % COLORS.length];
              const isToggling = togglingId === auto.id;
              const isDeleting = deletingId === auto.id;

              return (
                <div
                  key={auto.id}
                  className={`glass rounded-2xl p-5 flex items-center gap-4 transition-all duration-200 group ${
                    auto.enabled ? "hover:bg-white/4" : "opacity-55 hover:opacity-80"
                  }`}
                >
                  {/* Icon */}
                  <div className={`p-3 rounded-xl border ${colorBadge[color]} flex-shrink-0`}>
                    <Zap size={15} />
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    {/* Trigger keyword */}
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <span className="text-[10px] font-semibold uppercase tracking-wider text-zinc-600">
                        Trigger:
                      </span>
                      <code className="text-xs bg-white/8 text-indigo-300 px-2 py-0.5 rounded-md border border-indigo-500/20 font-mono">
                        {auto.trigger}
                      </code>
                    </div>
                    {/* Reply */}
                    <p className="text-sm text-zinc-400 truncate">
                      <span className="text-zinc-600 text-[10px] uppercase tracking-wider font-semibold mr-1.5">Reply:</span>
                      {auto.reply}
                    </p>
                  </div>

                  {/* Status badge */}
                  <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full border flex-shrink-0 ${
                    auto.enabled
                      ? "bg-emerald-500/15 text-emerald-400 border-emerald-500/25"
                      : "bg-zinc-800 text-zinc-600 border-zinc-700"
                  }`}>
                    {auto.enabled ? "Active" : "Paused"}
                  </span>

                  {/* Actions */}
                  <div className="flex items-center gap-1.5 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                    <button
                      onClick={() => openEdit(auto)}
                      className="p-1.5 rounded-lg text-zinc-600 hover:text-zinc-200 hover:bg-white/8 transition-all"
                      title="Edit"
                    >
                      <Pencil size={13} />
                    </button>
                    <button
                      onClick={() => handleDelete(auto.id)}
                      disabled={isDeleting}
                      className="p-1.5 rounded-lg text-zinc-600 hover:text-red-400 hover:bg-red-500/10 transition-all disabled:opacity-40"
                      title="Delete"
                    >
                      {isDeleting
                        ? <Loader2 size={13} className="animate-spin" />
                        : <Trash2 size={13} />
                      }
                    </button>
                  </div>

                  {/* Toggle */}
                  <button
                    onClick={() => handleToggle(auto)}
                    disabled={isToggling}
                    className="flex-shrink-0 transition-all disabled:opacity-50"
                    title={auto.enabled ? "Pause" : "Activate"}
                  >
                    {isToggling ? (
                      <Loader2 size={20} className="animate-spin text-zinc-500" />
                    ) : auto.enabled ? (
                      <ToggleRight size={28} className="text-indigo-400" />
                    ) : (
                      <ToggleLeft size={28} className="text-zinc-700" />
                    )}
                  </button>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* How it works hint */}
      {!loading && automations.length > 0 && (
        <div className="mt-6 p-4 rounded-xl bg-indigo-600/8 border border-indigo-500/15 flex items-start gap-3">
          <Zap size={15} className="text-indigo-400 flex-shrink-0 mt-0.5" />
          <p className="text-xs text-zinc-500">
            <span className="text-indigo-300 font-medium">How it works: </span>
            When a customer sends a message containing your trigger keyword, your page automatically replies with your set message — instantly, 24/7.
          </p>
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <AutomationModal
          pages={pages}
          editItem={editItem}
          selectedPageId={selectedPageId}
          onClose={closeModal}
          onSaved={loadAutomations}
        />
      )}
    </div>
  );
}

'@ | Set-Content -Path '.\app\dashboard\automation\page.tsx' -Encoding UTF8

@'
"use client";

import { useState, useEffect, useCallback } from "react";
import {
  Users, TrendingUp, Clock, Search,
  Filter, RefreshCw, MessageSquare, Inbox,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Lead = {
  id: string;
  page_id: string;
  page_name: string;
  name: string | null;
  message: string | null;
  created_at: string;
};

type Page = { id: string; name: string };

// ─── Helpers ──────────────────────────────────────────────────────────────────

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins  = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days  = Math.floor(diff / 86400000);
  if (mins  <  1) return "just now";
  if (mins  < 60) return `${mins}m ago`;
  if (hours < 24) return `${hours}h ago`;
  return `${days}d ago`;
}

function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("en-US", {
    month: "short", day: "numeric", year: "numeric",
  });
}

function getInitials(name: string | null): string {
  if (!name) return "?";
  return name.split(" ").map((w) => w[0]).join("").toUpperCase().slice(0, 2);
}

const AVATAR_COLORS = [
  "from-indigo-500 to-indigo-700",
  "from-sky-500 to-sky-700",
  "from-emerald-500 to-emerald-700",
  "from-purple-500 to-purple-700",
  "from-rose-500 to-rose-700",
  "from-amber-500 to-amber-700",
];

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function LeadsPage() {
  const [leads,          setLeads]          = useState<Lead[]>([]);
  const [pages,          setPages]          = useState<Page[]>([]);
  const [loading,        setLoading]        = useState(true);
  const [fetchError,     setFetchError]     = useState<string | null>(null);
  const [search,         setSearch]         = useState("");
  const [selectedPageId, setSelectedPageId] = useState("all");

  const loadLeads = useCallback(async () => {
    setLoading(true);
    setFetchError(null);
    try {
      const url = selectedPageId !== "all"
        ? `/api/leads?page_id=${selectedPageId}`
        : "/api/leads";

      const res = await fetch(url, { credentials: "include" });
      const data = await res.json();

      if (!res.ok) throw new Error(data.error ?? "Failed to load leads");
      setLeads(data.leads ?? []);
    } catch (e: unknown) {
      setFetchError(e instanceof Error ? e.message : "Failed to load leads.");
      setLeads([]);
    } finally {
      setLoading(false);
    }
  }, [selectedPageId]);

  // Load pages for filter tabs
  useEffect(() => {
    fetch("/api/pages", { credentials: "include" })
      .then((r) => r.json())
      .then((d) => setPages(d.pages ?? []))
      .catch(() => {});
  }, []);

  useEffect(() => { loadLeads(); }, [loadLeads]);

  // Filter by search
  const filtered = leads.filter((l) => {
    const q = search.toLowerCase();
    return (
      (l.name    ?? "").toLowerCase().includes(q) ||
      (l.message ?? "").toLowerCase().includes(q) ||
      l.page_name.toLowerCase().includes(q)
    );
  });

  // Stats
  const today = new Date().toDateString();
  const todayCount = leads.filter(
    (l) => new Date(l.created_at).toDateString() === today
  ).length;

  return (
    <div className="p-4 md:p-8 max-w-6xl animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between mb-8 gap-4 flex-wrap">
        <div>
          <p className="text-xs uppercase tracking-widest text-zinc-600 mb-1">CRM</p>
          <h1 className="font-display text-3xl font-700 text-white">Leads</h1>
          <p className="text-zinc-500 text-sm mt-1">
            {loading ? "Loading…" : `${leads.length} total leads captured`}
          </p>
        </div>
        <button
          onClick={loadLeads}
          disabled={loading}
          className="p-2.5 glass rounded-xl text-zinc-500 hover:text-zinc-300 border border-white/8 transition-all disabled:opacity-40"
        >
          <RefreshCw size={15} className={loading ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 mb-7">
        {[
          { label: "Total Leads", value: leads.length,  icon: Users,         color: "text-indigo-400" },
          { label: "New Today",   value: todayCount,    icon: Clock,         color: "text-sky-400"    },
          { label: "Pages",       value: pages.length,  icon: TrendingUp,    color: "text-emerald-400"},
        ].map(({ label, value, icon: Icon, color }) => (
          <div key={label} className="glass rounded-xl px-5 py-4 flex items-center gap-4">
            <Icon size={20} className={color} />
            <div>
              <p className="font-display text-2xl font-700 text-white">{value}</p>
              <p className="text-xs text-zinc-600">{label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3 mb-5 flex-wrap">
        {/* Search */}
        <div className="relative flex-1 max-w-sm">
          <Search size={14} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600" />
          <input
            type="text"
            placeholder="Search by name or message…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 bg-white/5 border border-white/8 rounded-xl text-sm text-zinc-300 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/40 transition-all"
          />
        </div>

        {/* Page filter */}
        {pages.length > 1 && (
          <div className="flex items-center gap-2 flex-wrap">
            <Filter size={13} className="text-zinc-600" />
            <button
              onClick={() => setSelectedPageId("all")}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg border transition-all ${
                selectedPageId === "all"
                  ? "bg-indigo-600 border-indigo-500 text-white"
                  : "glass border-white/8 text-zinc-400 hover:text-zinc-200"
              }`}
            >
              All Pages
            </button>
            {pages.map((p) => (
              <button
                key={p.id}
                onClick={() => setSelectedPageId(p.id)}
                className={`px-3 py-1.5 text-xs font-semibold rounded-lg border transition-all ${
                  selectedPageId === p.id
                    ? "bg-indigo-600 border-indigo-500 text-white"
                    : "glass border-white/8 text-zinc-400 hover:text-zinc-200"
                }`}
              >
                {p.name}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Error */}
      {fetchError && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
          <span>⚠</span><span>{fetchError}</span>
        </div>
      )}

      {/* Loading skeleton */}
      {loading && (
        <div className="glass rounded-2xl overflow-hidden">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="flex items-center gap-4 px-5 py-4 border-b border-white/5 animate-pulse">
              <div className="w-9 h-9 rounded-xl bg-white/8 flex-shrink-0" />
              <div className="flex-1 space-y-2">
                <div className="h-3 bg-white/8 rounded w-1/4" />
                <div className="h-2.5 bg-white/5 rounded w-2/3" />
              </div>
              <div className="h-2.5 bg-white/5 rounded w-16" />
            </div>
          ))}
        </div>
      )}

      {/* Empty state */}
      {!loading && filtered.length === 0 && (
        <div className="glass rounded-2xl p-14 text-center">
          <div className="w-14 h-14 rounded-2xl bg-indigo-600/15 border border-indigo-500/20 flex items-center justify-center mx-auto mb-4">
            <Inbox size={22} className="text-indigo-400" />
          </div>
          <h3 className="font-display text-lg font-700 text-white mb-2">
            {search ? "No leads match your search" : "No leads yet"}
          </h3>
          <p className="text-zinc-500 text-sm max-w-sm mx-auto">
            {search
              ? "Try a different search term."
              : "Leads will appear here automatically when customers message your connected Facebook pages."}
          </p>
        </div>
      )}

      {/* Leads list */}
      {!loading && filtered.length > 0 && (
        <div className="glass rounded-2xl overflow-hidden">
          {/* Table header */}
          <div className="grid grid-cols-12 gap-4 px-5 py-3 border-b border-white/6 bg-white/[0.02]">
            {["Customer", "Message", "Page", "Time"].map((h, i) => (
              <div
                key={h}
                className={`text-[10px] font-semibold uppercase tracking-widest text-zinc-600 ${
                  i === 0 ? "col-span-3" :
                  i === 1 ? "col-span-5" :
                  i === 2 ? "col-span-2" :
                            "col-span-2 text-right"
                }`}
              >
                {h}
              </div>
            ))}
          </div>

          {/* Rows */}
          {filtered.map((lead, idx) => {
            const avatarColor = AVATAR_COLORS[idx % AVATAR_COLORS.length];
            return (
              <div
                key={lead.id}
                className="grid grid-cols-12 gap-4 px-5 py-4 border-b border-white/4 last:border-0 hover:bg-white/[0.025] transition-colors items-center group"
              >
                {/* Customer */}
                <div className="col-span-3 flex items-center gap-3 min-w-0">
                  <div className={`w-9 h-9 rounded-xl bg-gradient-to-br ${avatarColor} flex items-center justify-center text-xs font-bold text-white flex-shrink-0`}>
                    {getInitials(lead.name)}
                  </div>
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-white truncate">
                      {lead.name ?? "Unknown Customer"}
                    </p>
                    <p className="text-[10px] text-zinc-600">{formatDate(lead.created_at)}</p>
                  </div>
                </div>

                {/* Message */}
                <div className="col-span-5 flex items-center gap-2 min-w-0">
                  <MessageSquare size={12} className="text-zinc-700 flex-shrink-0" />
                  <p className="text-sm text-zinc-400 truncate">
                    {lead.message ?? <span className="text-zinc-700 italic">No message</span>}
                  </p>
                </div>

                {/* Page */}
                <div className="col-span-2">
                  <span className="text-xs font-medium px-2 py-1 rounded-lg bg-indigo-600/10 border border-indigo-500/20 text-indigo-300 truncate block text-center">
                    {lead.page_name}
                  </span>
                </div>

                {/* Time */}
                <div className="col-span-2 text-right">
                  <span className="text-xs text-zinc-600">{timeAgo(lead.created_at)}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Result count */}
      {!loading && filtered.length > 0 && (
        <p className="text-xs text-zinc-700 mt-3 text-right">
          Showing {filtered.length} of {leads.length} leads
        </p>
      )}
    </div>
  );
}

'@ | Set-Content -Path '.\app\dashboard\leads\page.tsx' -Encoding UTF8

@'
"use client";

import { useState, useEffect, useCallback } from "react";
import {
  BrainCircuit, Save, RotateCcw, Sparkles, Shield,
  Globe, Loader2, SendHorizonal, CheckCircle2, AlertCircle,
  ChevronDown,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Settings = {
  enabled:       boolean;
  tone:          "friendly" | "professional" | "casual";
  language:      "bangla" | "english" | "mixed";
  persona:       string;
  business_name: string;
  business_info: string;
  max_replies:   number;
  confidence:    number;
  escalate:      boolean;
};

type Page = { id: string; name: string };

const DEFAULTS: Settings = {
  enabled:       true,
  tone:          "friendly",
  language:      "bangla",
  persona:       "",
  business_name: "",
  business_info: "",
  max_replies:   5,
  confidence:    75,
  escalate:      true,
};

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function AISettingsPage() {
  const [settings,    setSettings]    = useState<Settings>(DEFAULTS);
  const [pages,       setPages]       = useState<Page[]>([]);
  const [pageId,      setPageId]      = useState<string>("global");
  const [loading,     setLoading]     = useState(true);
  const [saving,      setSaving]      = useState(false);
  const [saveStatus,  setSaveStatus]  = useState<"idle" | "saved" | "error">("idle");
  const [fetchError,  setFetchError]  = useState<string | null>(null);

  // Test AI
  const [testMsg,     setTestMsg]     = useState("");
  const [testResult,  setTestResult]  = useState<string | null>(null);
  const [testError,   setTestError]   = useState<string | null>(null);
  const [testing,     setTesting]     = useState(false);

  // Load pages
  useEffect(() => {
    fetch("/api/pages", { credentials: "include" })
      .then((r) => r.json())
      .then((d) => setPages(d.pages ?? []))
      .catch(() => {});
  }, []);

  // Load settings when page selection changes
  const loadSettings = useCallback(async () => {
    setLoading(true);
    setFetchError(null);
    try {
      const url = pageId !== "global"
        ? `/api/ai-settings?page_id=${pageId}`
        : "/api/ai-settings";
      const res  = await fetch(url, { credentials: "include" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setSettings({ ...DEFAULTS, ...data.settings });
    } catch (e: unknown) {
      setFetchError(e instanceof Error ? e.message : "Failed to load settings.");
    } finally {
      setLoading(false);
    }
  }, [pageId]);

  useEffect(() => { loadSettings(); }, [loadSettings]);

  function update<K extends keyof Settings>(key: K, value: Settings[K]) {
    setSettings((prev) => ({ ...prev, [key]: value }));
    setSaveStatus("idle");
  }

  async function handleSave() {
    setSaving(true);
    setSaveStatus("idle");
    try {
      const res = await fetch("/api/ai-settings", {
        method:      "POST",
        credentials: "include",
        headers:     { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...settings,
          page_id: pageId !== "global" ? pageId : null,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setSaveStatus("saved");
      setTimeout(() => setSaveStatus("idle"), 3000);
    } catch {
      setSaveStatus("error");
    } finally {
      setSaving(false);
    }
  }

  async function handleTest() {
    if (!testMsg.trim()) return;
    setTesting(true);
    setTestResult(null);
    setTestError(null);
    try {
      const res = await fetch("/api/ai-reply", {
        method:      "POST",
        credentials: "include",
        headers:     { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: testMsg.trim(),
          page_id: pageId !== "global" ? pageId : undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        if (data.code === "NO_API_KEY") {
          setTestError("⚠ GROQ_API_KEY not set. Add it to your .env.local file.");
        } else {
          setTestError(data.error ?? "AI error");
        }
      } else {
        setTestResult(data.reply);
      }
    } catch {
      setTestError("Network error. Please try again.");
    } finally {
      setTesting(false);
    }
  }

  if (loading) {
    return (
      <div className="p-4 md:p-8 max-w-3xl animate-fade-in">
        <div className="mb-8">
          <div className="h-4 bg-white/5 rounded w-24 mb-3 animate-pulse" />
          <div className="h-8 bg-white/8 rounded w-48 mb-2 animate-pulse" />
          <div className="h-3 bg-white/5 rounded w-64 animate-pulse" />
        </div>
        <div className="space-y-4">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="glass rounded-2xl p-6 animate-pulse h-36" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 md:p-8 max-w-3xl animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between mb-8 gap-4 flex-wrap">
        <div>
          <p className="text-xs uppercase tracking-widest text-zinc-600 mb-1">Configuration</p>
          <h1 className="font-display text-3xl font-700 text-white">AI Settings</h1>
          <p className="text-zinc-500 text-sm mt-1">
            Configure how AI replies to your customers automatically.
          </p>
        </div>
        {/* Page selector */}
        <div className="relative">
          <select
            value={pageId}
            onChange={(e) => setPageId(e.target.value)}
            className="bg-white/5 border border-white/8 rounded-xl px-4 py-2.5 pr-9 text-sm text-zinc-300 focus:outline-none focus:border-indigo-500 transition-all appearance-none"
          >
            <option value="global">Global (All Pages)</option>
            {pages.map((p) => (
              <option key={p.id} value={p.id}>{p.name}</option>
            ))}
          </select>
          <ChevronDown size={13} className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-600 pointer-events-none" />
        </div>
      </div>

      {fetchError && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
          <span>⚠</span><span>{fetchError}</span>
        </div>
      )}

      <div className="space-y-5">

        {/* ── AI Enable Toggle ── */}
        <div className="glass rounded-2xl p-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-indigo-600/15 border border-indigo-500/20 text-indigo-300">
              <BrainCircuit size={16} />
            </div>
            <div>
              <p className="font-semibold text-white text-sm">AI Auto Reply</p>
              <p className="text-xs text-zinc-600 mt-0.5">
                {settings.enabled ? "AI is active — replying to messages" : "AI is paused — not replying"}
              </p>
            </div>
          </div>
          <button
            onClick={() => update("enabled", !settings.enabled)}
            className={`w-11 h-6 rounded-full relative transition-all duration-200 ${
              settings.enabled ? "bg-indigo-600" : "bg-zinc-700"
            }`}
          >
            <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow transition-all duration-200 ${
              settings.enabled ? "left-5" : "left-0.5"
            }`} />
          </button>
        </div>

        {/* ── Business Info ── */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="p-2.5 rounded-xl bg-emerald-600/15 border border-emerald-500/20 text-emerald-300">
              <Sparkles size={16} />
            </div>
            <div>
              <h2 className="font-semibold text-white text-sm">Business Information</h2>
              <p className="text-xs text-zinc-600 mt-0.5">AI uses this to generate accurate replies</p>
            </div>
          </div>
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                Business Name
              </label>
              <input
                type="text"
                value={settings.business_name}
                onChange={(e) => update("business_name", e.target.value)}
                placeholder="e.g. Dhaka Fashion House"
                className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                Business Description
              </label>
              <textarea
                value={settings.business_info}
                onChange={(e) => update("business_info", e.target.value)}
                placeholder={"e.g. We sell women''s clothing. Price 500-2000tk. Delivery all over Bangladesh."}
                rows={3}
                className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all resize-none"
              />
              <p className="text-[11px] text-zinc-700 mt-1.5">
                The more detail you add, the better AI replies will be
              </p>
            </div>
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                Opening Greeting
              </label>
              <textarea
                value={settings.persona}
                onChange={(e) => update("persona", e.target.value)}
                rows={2}
                className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all resize-none"
              />
            </div>
          </div>
        </div>

        {/* ── Tone & Language ── */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="p-2.5 rounded-xl bg-purple-600/15 border border-purple-500/20 text-purple-300">
              <Globe size={16} />
            </div>
            <div>
              <h2 className="font-semibold text-white text-sm">Tone & Language</h2>
              <p className="text-xs text-zinc-600 mt-0.5">How AI communicates with customers</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-6">
            {/* Tone */}
            <div>
              <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider block mb-3">
                Reply Tone
              </label>
              <div className="space-y-2.5">
                {[
                  { value: "friendly",     label: "Friendly",      desc: "Warm + emoji 😊" },
                  { value: "professional", label: "Professional",  desc: "Formal + polite" },
                  { value: "casual",       label: "Casual",        desc: "Relaxed + natural" },
                ].map((t) => (
                  <label key={t.value} className="flex items-start gap-3 cursor-pointer group">
                    <div
                      className={`mt-0.5 w-4 h-4 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all ${
                        settings.tone === t.value
                          ? "border-indigo-500 bg-indigo-500"
                          : "border-zinc-700 group-hover:border-zinc-500"
                      }`}
                      onClick={() => update("tone", t.value as Settings["tone"])}
                    >
                      {settings.tone === t.value && (
                        <div className="w-1.5 h-1.5 rounded-full bg-white" />
                      )}
                    </div>
                    <div>
                      <p className="text-sm text-zinc-300">{t.label}</p>
                      <p className="text-[11px] text-zinc-600">{t.desc}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            {/* Language */}
            <div>
              <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider block mb-3">
                Reply Language
              </label>
              <div className="space-y-2.5">
                {[
                  { value: "bangla",  label: "বাংলা",         desc: "Full Bangla replies" },
                  { value: "english", label: "English",       desc: "Full English replies" },
                  { value: "mixed",   label: "Mixed",         desc: "Banglish (both)" },
                ].map((l) => (
                  <label key={l.value} className="flex items-start gap-3 cursor-pointer group">
                    <div
                      className={`mt-0.5 w-4 h-4 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all ${
                        settings.language === l.value
                          ? "border-indigo-500 bg-indigo-500"
                          : "border-zinc-700 group-hover:border-zinc-500"
                      }`}
                      onClick={() => update("language", l.value as Settings["language"])}
                    >
                      {settings.language === l.value && (
                        <div className="w-1.5 h-1.5 rounded-full bg-white" />
                      )}
                    </div>
                    <div>
                      <p className="text-sm text-zinc-300">{l.label}</p>
                      <p className="text-[11px] text-zinc-600">{l.desc}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* ── Safety & Limits ── */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="p-2.5 rounded-xl bg-sky-600/15 border border-sky-500/20 text-sky-300">
              <Shield size={16} />
            </div>
            <div>
              <h2 className="font-semibold text-white text-sm">Safety & Limits</h2>
              <p className="text-xs text-zinc-600 mt-0.5">Control AI behavior</p>
            </div>
          </div>
          <div className="space-y-5">
            {/* Confidence */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Confidence Threshold
                </label>
                <span className="text-xs text-indigo-400 font-mono font-semibold">
                  {settings.confidence}%
                </span>
              </div>
              <input
                type="range"
                min={50} max={100}
                value={settings.confidence}
                onChange={(e) => update("confidence", Number(e.target.value))}
                className="w-full accent-indigo-500"
              />
              <p className="text-[11px] text-zinc-700 mt-1.5">
                AI only replies when confidence ≥ {settings.confidence}%
              </p>
            </div>

            {/* Max replies */}
            <div>
              <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider block mb-2">
                Max AI Replies per Thread
              </label>
              <div className="flex items-center gap-2">
                {[3, 5, 10, 20, 50].map((n) => (
                  <button
                    key={n}
                    onClick={() => update("max_replies", n)}
                    className={`px-4 py-2 rounded-xl text-sm font-medium transition-all border ${
                      settings.max_replies === n
                        ? "bg-indigo-600 border-indigo-500 text-white"
                        : "bg-white/5 border-white/8 text-zinc-400 hover:text-zinc-200"
                    }`}
                  >
                    {n}
                  </button>
                ))}
              </div>
            </div>

            {/* Escalate */}
            <div className="flex items-center justify-between p-4 bg-white/4 rounded-xl border border-white/6">
              <div>
                <p className="text-sm font-medium text-zinc-300">Escalate to human</p>
                <p className="text-xs text-zinc-600 mt-0.5">
                  Hand off when AI can&apos;t resolve the issue
                </p>
              </div>
              <button
                onClick={() => update("escalate", !settings.escalate)}
                className={`w-10 h-[22px] rounded-full relative transition-all duration-200 ${
                  settings.escalate ? "bg-indigo-600" : "bg-zinc-700"
                }`}
              >
                <div className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all duration-200 ${
                  settings.escalate ? "left-5" : "left-0.5"
                }`} />
              </button>
            </div>
          </div>
        </div>

        {/* ── Live AI Test ── */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="p-2.5 rounded-xl bg-amber-600/15 border border-amber-500/20 text-amber-300">
              <SendHorizonal size={16} />
            </div>
            <div>
              <h2 className="font-semibold text-white text-sm">Test AI Reply</h2>
              <p className="text-xs text-zinc-600 mt-0.5">
                Send a test message to see what AI would reply
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3 mb-4">
            <input
              type="text"
              value={testMsg}
              onChange={(e) => setTestMsg(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleTest()}
              placeholder="e.g. What is the price? / How to order?"
              className="flex-1 bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/40 transition-all"
            />
            <button
              onClick={handleTest}
              disabled={testing || !testMsg.trim()}
              className="px-5 py-3 bg-amber-600 hover:bg-amber-500 disabled:opacity-40 text-white text-sm font-semibold rounded-xl transition-all flex items-center gap-2 whitespace-nowrap"
            >
              {testing
                ? <><Loader2 size={14} className="animate-spin" /> Testing…</>
                : <><SendHorizonal size={14} /> Test</>
              }
            </button>
          </div>

          {/* Test result */}
          {testResult && (
            <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20">
              <div className="flex items-center gap-2 mb-2">
                <CheckCircle2 size={14} className="text-emerald-400" />
                <span className="text-xs font-semibold text-emerald-400 uppercase tracking-wider">
                  AI Reply
                </span>
              </div>
              <p className="text-sm text-zinc-300 leading-relaxed">{testResult}</p>
            </div>
          )}

          {testError && (
            <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20">
              <div className="flex items-center gap-2 mb-1">
                <AlertCircle size={14} className="text-red-400" />
                <span className="text-xs font-semibold text-red-400 uppercase tracking-wider">Error</span>
              </div>
              <p className="text-sm text-red-400">{testError}</p>
              {testError.includes("GROQ_API_KEY") && (
                <div className="mt-3 p-3 bg-white/5 rounded-lg text-xs text-zinc-500 font-mono">
                  Add to .env.local:<br />
                  GROQ_API_KEY=your_key_here<br />
                  <span className="text-indigo-400">→ Get free key at console.groq.com</span>
                </div>
              )}
            </div>
          )}
        </div>

        {/* ── Save Actions ── */}
        <div className="flex items-center justify-between">
          <button
            onClick={() => { setSettings(DEFAULTS); setSaveStatus("idle"); }}
            className="flex items-center gap-2 px-4 py-2.5 text-sm text-zinc-500 hover:text-zinc-300 glass rounded-xl border border-white/8 transition-all"
          >
            <RotateCcw size={14} />
            Reset defaults
          </button>

          <button
            onClick={handleSave}
            disabled={saving}
            className={`flex items-center gap-2 px-6 py-2.5 text-sm font-semibold rounded-xl transition-all glow-sm ${
              saveStatus === "saved"
                ? "bg-emerald-600 text-white"
                : saveStatus === "error"
                ? "bg-red-600 text-white"
                : "bg-indigo-600 hover:bg-indigo-500 text-white"
            } disabled:opacity-50`}
          >
            {saving ? (
              <><Loader2 size={14} className="animate-spin" /> Saving…</>
            ) : saveStatus === "saved" ? (
              <><CheckCircle2 size={14} /> Saved!</>
            ) : saveStatus === "error" ? (
              <><AlertCircle size={14} /> Failed — retry</>
            ) : (
              <><Save size={14} /> Save Settings</>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

'@ | Set-Content -Path '.\app\dashboard\ai-settings\page.tsx' -Encoding UTF8

@'
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

'@ | Set-Content -Path '.\app\dashboard\billing\page.tsx' -Encoding UTF8

@'
import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title:       "PageFlow — Facebook Automation",
  description: "AI-powered Facebook automation for businesses. Auto-reply, capture leads, and grow sales.",
  manifest:    "/manifest.json",
  appleWebApp: {
    capable:        true,
    statusBarStyle: "black-translucent",
    title:          "PageFlow",
  },
  formatDetection: { telephone: false },
  openGraph: {
    title:       "PageFlow",
    description: "AI-powered Facebook automation",
    type:        "website",
  },
};

export const viewport: Viewport = {
  width:              "device-width",
  initialScale:       1,
  maximumScale:       1,
  userScalable:       false,
  themeColor:         "#6366f1",
  viewportFit:        "cover",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,300;0,9..40,400;0,9..40,500;0,9..40,600;1,9..40,300&family=Syne:wght@600;700;800&display=swap"
          rel="stylesheet"
        />

        {/* PWA Icons */}
        <link rel="icon"             href="/icons/icon-192.png" />
        <link rel="apple-touch-icon" href="/icons/icon-192.png" />
        <link rel="apple-touch-icon" sizes="152x152" href="/icons/icon-152.png" />
        <link rel="apple-touch-icon" sizes="144x144" href="/icons/icon-144.png" />

        {/* iOS PWA splash screen color */}
        <meta name="apple-mobile-web-app-capable"          content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="mobile-web-app-capable"                content="yes" />

        {/* Register service worker */}
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if (''serviceWorker'' in navigator) {
                window.addEventListener(''load'', function() {
                  navigator.serviceWorker.register(''/sw.js'').then(function(reg) {
                    console.log(''[PWA] Service worker registered:'', reg.scope);
                  }).catch(function(err) {
                    console.log(''[PWA] Service worker failed:'', err);
                  });
                });
              }
            `,
          }}
        />
      </head>
      <body className="bg-[#0a0a0f] text-zinc-100 antialiased font-sans">
        {children}
      </body>
    </html>
  );
}

'@ | Set-Content -Path '.\app\layout.tsx' -Encoding UTF8

@'
import Sidebar from "@/components/Sidebar";
import MobileNav from "@/components/MobileNav";
import MobileHeader from "@/components/MobileHeader";
import PWAInstallPrompt from "@/components/PWAInstallPrompt";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-[#0a0a0f]">
      <div className="hidden md:block">
        <Sidebar />
      </div>
      <MobileHeader />
      <main className="min-h-screen md:ml-60 pt-[calc(56px+env(safe-area-inset-top))] pb-[calc(72px+env(safe-area-inset-bottom))] md:pt-0 md:pb-0">
        {children}
      </main>
      <MobileNav />
      <PWAInstallPrompt />
    </div>
  );
}

'@ | Set-Content -Path '.\app\dashboard\layout.tsx' -Encoding UTF8

@'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --font-sans: "DM Sans", system-ui, sans-serif;
  --font-display: "Syne", sans-serif;
}

* {
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
}

body {
  font-family: var(--font-sans);
}

.font-display {
  font-family: var(--font-display);
}

/* Scrollbar styling */
::-webkit-scrollbar {
  width: 4px;
  height: 4px;
}
::-webkit-scrollbar-track {
  background: transparent;
}
::-webkit-scrollbar-thumb {
  background: #3f3f46;
  border-radius: 99px;
}
::-webkit-scrollbar-thumb:hover {
  background: #52525b;
}

/* Glass morphism utility */
.glass {
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.06);
}

/* Gradient text */
.gradient-text {
  background: linear-gradient(135deg, #818cf8 0%, #c084fc 50%, #f472b6 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

/* Glow effects */
.glow-accent {
  box-shadow: 0 0 24px rgba(99, 102, 241, 0.35);
}

.glow-sm {
  box-shadow: 0 0 12px rgba(99, 102, 241, 0.2);
}

/* Sidebar active indicator */
.nav-active {
  background: linear-gradient(90deg, rgba(99,102,241,0.18) 0%, rgba(99,102,241,0.04) 100%);
  border-left: 2px solid #6366f1;
}

/* Animated gradient background */
@keyframes gradientShift {
  0%   { background-position: 0% 50%; }
  50%  { background-position: 100% 50%; }
  100% { background-position: 0% 50%; }
}

.animated-gradient {
  background: linear-gradient(-45deg, #0a0a0f, #0f0f1a, #0e0b1f, #090912);
  background-size: 400% 400%;
  animation: gradientShift 15s ease infinite;
}

@keyframes pulse-ring {
  0%   { transform: scale(0.8); opacity: 0.8; }
  100% { transform: scale(1.6); opacity: 0; }
}

.pulse-dot::before {
  content: "";
  position: absolute;
  inset: 0;
  border-radius: 50%;
  background: currentColor;
  animation: pulse-ring 1.5s ease-out infinite;
}

/* ─── PWA / Mobile styles ──────────────────────────────────────────────────── */

/* Prevent text size adjustment on orientation change */
html {
  -webkit-text-size-adjust: 100%;
  text-size-adjust: 100%;
}

/* Safe area support for notched phones */
body {
  padding-env: safe-area-inset-top safe-area-inset-right
               safe-area-inset-bottom safe-area-inset-left;
}

/* Remove tap highlight on mobile */
* {
  -webkit-tap-highlight-color: transparent;
}

/* Smooth scrolling on iOS */
.scroll-smooth-ios {
  -webkit-overflow-scrolling: touch;
  overflow-y: auto;
}

/* Mobile card touch feedback */
@media (max-width: 768px) {
  .glass {
    /* Slightly more opaque on mobile for readability */
    background: rgba(255, 255, 255, 0.05);
  }

  /* Larger touch targets on mobile */
  button, a {
    min-height: 36px;
  }
}

/* PWA standalone mode — hide browser UI */
@media (display-mode: standalone) {
  body {
    user-select: none;
  }
}

/* Install prompt animation */
@keyframes slideUp {
  from { transform: translateY(100%); opacity: 0; }
  to   { transform: translateY(0);    opacity: 1; }
}

.install-prompt {
  animation: slideUp 0.3s ease forwards;
}

'@ | Set-Content -Path '.\app\globals.css' -Encoding UTF8

@'
import Link from "next/link";

export default function HomePage() {
  return (
    <main className="animated-gradient min-h-screen flex flex-col items-center justify-center relative overflow-hidden px-6">
      {/* Decorative orbs */}
      <div className="absolute top-[-20%] left-[-10%] w-[600px] h-[600px] bg-indigo-600/10 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-[-20%] right-[-10%] w-[500px] h-[500px] bg-purple-600/10 rounded-full blur-[120px] pointer-events-none" />

      {/* Grid overlay */}
      <div
        className="absolute inset-0 opacity-[0.03]"
        style={{
          backgroundImage:
            "linear-gradient(rgba(255,255,255,0.5) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.5) 1px, transparent 1px)",
          backgroundSize: "60px 60px",
        }}
      />

      {/* Nav */}
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

      <div className="relative z-10 text-center max-w-3xl animate-fade-in">
        {/* Badge */}
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full glass text-xs font-medium text-indigo-300 mb-8 tracking-wider uppercase border border-indigo-500/20">
          <span className="relative flex h-1.5 w-1.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-indigo-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-indigo-400" />
          </span>
          AI-powered · Bangla + English · Made for Bangladesh
        </div>

        {/* Headline */}
        <h1 className="font-display text-6xl md:text-7xl font-800 leading-[1.05] mb-6 tracking-tight">
          <span className="text-white">Automate your</span>
          <br />
          <span className="gradient-text">Facebook replies</span>
        </h1>

        <p className="text-zinc-400 text-lg md:text-xl leading-relaxed mb-10 max-w-xl mx-auto">
          Connect your page, set keyword rules, and let AI reply to customers automatically —
          in Bangla or English. Save time, increase sales.
        </p>

        {/* CTAs */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <Link
            href="/auth"
            className="px-8 py-3.5 bg-indigo-600 hover:bg-indigo-500 text-white font-semibold rounded-xl transition-all duration-200 glow-accent hover:glow-sm text-sm tracking-wide"
          >
            Start for free →
          </Link>
          <Link
            href="/pricing"
            className="px-8 py-3.5 glass hover:bg-white/5 text-zinc-300 font-semibold rounded-xl transition-all duration-200 text-sm tracking-wide border border-white/8"
          >
            View pricing
          </Link>
        </div>

        {/* Features row */}
        <div className="mt-12 flex items-center justify-center gap-6 flex-wrap text-xs text-zinc-600">
          {[
            "✓ Free plan available",
            "✓ Bangla AI replies",
            "✓ bKash & Nagad payment",
            "✓ No credit card required",
          ].map((f) => (
            <span key={f} className="text-zinc-500">{f}</span>
          ))}
        </div>

        {/* Stats row */}
        <div className="mt-12 flex items-center justify-center gap-10 text-center">
          {[
            { value: "BDT 799", label: "Pro plan/month" },
            { value: "99%",   label: "Uptime SLA"     },
            { value: "24/7",  label: "Auto replies"   },
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

'@ | Set-Content -Path '.\app\page.tsx' -Encoding UTF8

@'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard, FileText, Zap,
  Users, CreditCard,
} from "lucide-react";

const navItems = [
  { href: "/dashboard",             label: "Home",       icon: LayoutDashboard },
  { href: "/dashboard/pages",       label: "Pages",      icon: FileText        },
  { href: "/dashboard/automation",  label: "Rules",      icon: Zap             },
  { href: "/dashboard/leads",       label: "Leads",      icon: Users           },
  { href: "/dashboard/billing",     label: "Billing",    icon: CreditCard      },
];

export default function MobileNav() {
  const pathname = usePathname();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 md:hidden border-t border-white/8"
      style={{
        background:  "rgba(10,10,15,0.95)",
        backdropFilter: "blur(20px)",
        paddingBottom: "env(safe-area-inset-bottom)",
      }}
    >
      <div className="flex items-center justify-around px-2 py-2">
        {navItems.map(({ href, label, icon: Icon }) => {
          const isActive =
            href === "/dashboard" ? pathname === href : pathname.startsWith(href);

          return (
            <Link
              key={href}
              href={href}
              className={`flex flex-col items-center gap-0.5 px-3 py-2 rounded-xl transition-all duration-150 min-w-0 flex-1 ${
                isActive
                  ? "text-indigo-400"
                  : "text-zinc-600 hover:text-zinc-400"
              }`}
            >
              <div className={`p-1.5 rounded-xl transition-all ${
                isActive ? "bg-indigo-600/20" : ""
              }`}>
                <Icon size={20} strokeWidth={isActive ? 2.5 : 1.8} />
              </div>
              <span className={`text-[10px] font-semibold tracking-wide ${
                isActive ? "text-indigo-400" : "text-zinc-600"
              }`}>
                {label}
              </span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}

'@ | Set-Content -Path '.\components\MobileNav.tsx' -Encoding UTF8

@'
"use client";

import { usePathname, useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase";
import { Sparkles, LogOut, Bell } from "lucide-react";
import Link from "next/link";

const supabase = createClient();

const PAGE_TITLES: Record<string, string> = {
  "/dashboard":             "Dashboard",
  "/dashboard/pages":       "Facebook Pages",
  "/dashboard/automation":  "Automation",
  "/dashboard/ai-settings": "AI Settings",
  "/dashboard/leads":       "Leads",
  "/dashboard/billing":     "Billing",
};

export default function MobileHeader() {
  const pathname = usePathname();
  const router   = useRouter();

  const title = PAGE_TITLES[pathname] ?? "PageFlow";

  async function handleSignOut() {
    await supabase.auth.signOut();
    router.push("/auth");
    router.refresh();
  }

  return (
    <header
      className="fixed top-0 left-0 right-0 z-50 md:hidden border-b border-white/6 flex items-center justify-between px-4"
      style={{
        background:     "rgba(10,10,15,0.95)",
        backdropFilter: "blur(20px)",
        paddingTop:     "env(safe-area-inset-top)",
        height:         "calc(56px + env(safe-area-inset-top))",
      }}
    >
      {/* Logo */}
      <Link href="/dashboard" className="flex items-center gap-2">
        <div className="w-7 h-7 rounded-lg bg-indigo-600 flex items-center justify-center">
          <Sparkles size={14} className="text-white" />
        </div>
        <span className="font-display text-base font-700 text-white">{title}</span>
      </Link>

      {/* Right actions */}
      <div className="flex items-center gap-1">
        <button className="p-2 rounded-xl text-zinc-500 hover:text-zinc-300 hover:bg-white/8 transition-all">
          <Bell size={18} />
        </button>
        <button
          onClick={handleSignOut}
          className="p-2 rounded-xl text-zinc-500 hover:text-red-400 hover:bg-red-500/10 transition-all"
        >
          <LogOut size={18} />
        </button>
      </div>
    </header>
  );
}

'@ | Set-Content -Path '.\components\MobileHeader.tsx' -Encoding UTF8

@'
"use client";

import { useState, useEffect } from "react";
import { Download, X, Sparkles } from "lucide-react";

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
}

export default function PWAInstallPrompt() {
  const [prompt,    setPrompt]    = useState<BeforeInstallPromptEvent | null>(null);
  const [visible,   setVisible]   = useState(false);
  const [installed, setInstalled] = useState(false);

  useEffect(() => {
    // Check if already installed
    if (window.matchMedia("(display-mode: standalone)").matches) {
      setInstalled(true);
      return;
    }

    // Check if dismissed before
    if (localStorage.getItem("pwa-dismissed")) return;

    const handler = (e: Event) => {
      e.preventDefault();
      setPrompt(e as BeforeInstallPromptEvent);
      // Show prompt after 3 seconds
      setTimeout(() => setVisible(true), 3000);
    };

    window.addEventListener("beforeinstallprompt", handler);
    window.addEventListener("appinstalled", () => setInstalled(true));

    return () => {
      window.removeEventListener("beforeinstallprompt", handler);
    };
  }, []);

  async function handleInstall() {
    if (!prompt) return;
    await prompt.prompt();
    const { outcome } = await prompt.userChoice;
    if (outcome === "accepted") {
      setInstalled(true);
    }
    setVisible(false);
  }

  function handleDismiss() {
    setVisible(false);
    localStorage.setItem("pwa-dismissed", "1");
  }

  if (!visible || installed) return null;

  return (
    <div className="fixed bottom-[80px] left-4 right-4 z-[100] md:left-auto md:right-6 md:w-80 install-prompt">
      <div className="glass rounded-2xl p-4 border border-indigo-500/30 shadow-2xl shadow-black/50">
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 rounded-xl bg-indigo-600 flex items-center justify-center flex-shrink-0">
            <Sparkles size={18} className="text-white" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="font-semibold text-white text-sm">Install PageFlow</p>
            <p className="text-zinc-500 text-xs mt-0.5">
              Add to your home screen for instant access — works offline too
            </p>
          </div>
          <button
            onClick={handleDismiss}
            className="p-1 rounded-lg text-zinc-600 hover:text-zinc-400 transition-colors flex-shrink-0"
          >
            <X size={14} />
          </button>
        </div>

        <div className="flex items-center gap-2 mt-3">
          <button
            onClick={handleInstall}
            className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold rounded-xl transition-all"
          >
            <Download size={13} />
            Install App
          </button>
          <button
            onClick={handleDismiss}
            className="px-4 py-2.5 glass border border-white/8 text-zinc-400 text-xs font-medium rounded-xl transition-all"
          >
            Not now
          </button>
        </div>
      </div>
    </div>
  );
}

'@ | Set-Content -Path '.\components\PWAInstallPrompt.tsx' -Encoding UTF8
