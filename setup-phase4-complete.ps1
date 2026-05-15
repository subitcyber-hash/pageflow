# Phase 4 COMPLETE setup - all files
$OutputEncoding = [System.Text.Encoding]::UTF8

New-Item -ItemType Directory -Force -Path ".\app" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\ai-reply" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\automation" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\pages" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\payment" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\payment\sslcommerz" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\payment\verify" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\subscription" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard\billing" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\pricing" | Out-Null
New-Item -ItemType Directory -Force -Path ".\components" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib\db" | Out-Null

@'
import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { PagesService } from "@/lib/db/pages.service";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS, canAddPage } from "@/lib/plans";

export async function GET() {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });
    const { data, error } = await PagesService.getAll(supabase, user.id);

    if (error) {
      return error.code === "NOT_FOUND"
        ? ApiError.notFound("Pages")
        : ApiError.internal(error.message);
    }

    return NextResponse.json({ pages: data, total: data.length });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/pages]", err);
    return ApiError.internal();
  }
}

export async function POST(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    // ── Plan limit check ──────────────────────────────────────
    const plan = await SubscriptionService.getUserPlan(supabase, user.id);
    const { data: existing } = await PagesService.getAll(supabase, user.id);
    const currentCount = existing?.length ?? 0;

    if (!canAddPage(plan, currentCount)) {
      const limit = PLANS[plan].pages;
      return NextResponse.json(
        {
          error:    `Your ${PLANS[plan].name} plan allows a maximum of ${limit} page${limit === 1 ? "" : "s"}. Upgrade to add more.`,
          code:     "PLAN_LIMIT_REACHED",
          limit,
          current:  currentCount,
          plan,
          upgradeUrl: "/dashboard/billing",
        },
        { status: 403 }
      );
    }
    // ─────────────────────────────────────────────────────────

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const name = sanitizeString(body.name);
    if (!name) {
      return ApiError.badRequest("''name'' is required and must be a non-empty string under 255 characters");
    }

    const category = sanitizeString(body.category ?? "Business") ?? "Business";

    const { data, error } = await PagesService.create(supabase, user.id, { name, category });

    if (error) return ApiError.internal(error.message);

    return NextResponse.json({ page: data }, { status: 201 });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/pages]", err);
    return ApiError.internal();
  }
}

'@ | Set-Content -Path '.\app\api\pages\route.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { AutomationService } from "@/lib/db/automation.service";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS, canAddAutomation } from "@/lib/plans";

export async function GET(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    const { searchParams } = new URL(request.url);
    const pageId = searchParams.get("page_id");

    if (!pageId) return ApiError.badRequest("''page_id'' query parameter is required");

    const { data, error } = await AutomationService.getByPage(supabase, user.id, pageId);

    if (error) {
      return error.code === "NOT_FOUND"
        ? ApiError.notFound("Automations")
        : ApiError.internal(error.message);
    }

    return NextResponse.json({ automations: data, total: data.length });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/automation]", err);
    return ApiError.internal();
  }
}

export async function POST(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const pageId = sanitizeString(body.page_id);
    if (!pageId) return ApiError.badRequest("''page_id'' is required");

    // ── Plan limit check ──────────────────────────────────────
    const plan = await SubscriptionService.getUserPlan(supabase, user.id);
    const { data: existing } = await AutomationService.getByPage(supabase, user.id, pageId);
    const currentCount = existing?.length ?? 0;

    if (!canAddAutomation(plan, currentCount)) {
      const limit = PLANS[plan].automations;
      return NextResponse.json(
        {
          error:      `Your ${PLANS[plan].name} plan allows ${limit} automation rule${limit === 1 ? "" : "s"} per page. Upgrade to add more.`,
          code:       "PLAN_LIMIT_REACHED",
          limit,
          current:    currentCount,
          plan,
          upgradeUrl: "/dashboard/billing",
        },
        { status: 403 }
      );
    }
    // ─────────────────────────────────────────────────────────

    const trigger = sanitizeString(body.trigger, 500);
    if (!trigger) return ApiError.badRequest("''trigger'' is required and must be under 500 characters");

    const reply = sanitizeString(body.reply, 2000);
    if (!reply) return ApiError.badRequest("''reply'' is required and must be under 2000 characters");

    const { data, error } = await AutomationService.create(supabase, user.id, {
      page_id: pageId,
      trigger,
      reply,
    });

    if (error) {
      return error.code === "NOT_FOUND"
        ? ApiError.notFound("Page")
        : ApiError.internal(error.message);
    }

    return NextResponse.json({ automation: data }, { status: 201 });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/automation]", err);
    return ApiError.internal();
  }
}

'@ | Set-Content -Path '.\app\api\automation\route.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { generateReply, getFallbackReply } from "@/lib/ai/groq";
import { AISettingsService } from "@/lib/db/ai-settings.service";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS, canUseAI } from "@/lib/plans";

export async function POST(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const message = sanitizeString(body.message, 1000);
    if (!message) return ApiError.badRequest("''message'' is required");

    // ── Plan limit check ──────────────────────────────────────
    const plan = await SubscriptionService.getUserPlan(supabase, user.id);

    if (!canUseAI(plan)) {
      return NextResponse.json(
        {
          error:      `AI replies are not available on the ${PLANS[plan].name} plan. Upgrade to Pro or Business.`,
          code:       "PLAN_LIMIT_REACHED",
          plan,
          upgradeUrl: "/dashboard/billing",
        },
        { status: 403 }
      );
    }
    // ─────────────────────────────────────────────────────────

    const pageId = body.page_id as string | undefined;

    const { data: settings } = await AISettingsService.get(
      supabase,
      user.id,
      pageId ?? null
    );

    if (settings && !settings.enabled) {
      return NextResponse.json({
        reply:   getFallbackReply(settings.language),
        source:  "fallback",
        reason:  "AI disabled",
      });
    }

    if (!process.env.GROQ_API_KEY) {
      return NextResponse.json(
        {
          error: "GROQ_API_KEY not configured",
          code:  "NO_API_KEY",
          hint:  "Add GROQ_API_KEY to your .env.local file. Get free key at console.groq.com",
        },
        { status: 503 }
      );
    }

    const result = await generateReply({
      userMessage:  message,
      businessName: settings?.business_name || undefined,
      businessInfo: settings?.business_info || undefined,
      persona:      settings?.persona       || undefined,
      language:     settings?.language      ?? "bangla",
      tone:         settings?.tone          ?? "friendly",
      maxTokens:    300,
    });

    if (result.error) {
      return NextResponse.json({ error: result.error, code: "AI_ERROR" }, { status: 500 });
    }

    return NextResponse.json({
      reply:      result.reply,
      source:     "groq",
      tokensUsed: result.tokensUsed,
      plan,
      settings: {
        tone:     settings?.tone     ?? "friendly",
        language: settings?.language ?? "bangla",
      },
    });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/ai-reply]", err);
    return ApiError.internal();
  }
}

'@ | Set-Content -Path '.\app\api\ai-reply\route.ts' -Encoding UTF8

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
    { label: "Connected Pages",    value: totalPages.toString(),   change: `of ${planDetails.pages === -1 ? "∞" : planDetails.pages} allowed`,  icon: TrendingUp,    color: "indigo" },
    { label: "Total Leads",        value: totalLeads.toString(),   change: "Captured from messages",  icon: Users,         color: "purple" },
    { label: "Active Automations", value: activeAutos.toString(),  change: `${totalAutos} rules total`,               icon: Zap,           color: "sky"    },
    { label: "AI Replies",         value: planDetails.aiReplies === 0 ? "—" : planDetails.aiReplies === -1 ? "∞" : `${planDetails.aiReplies}/mo`, change: currentPlan === "free" ? "Upgrade to enable" : "Monthly limit", icon: MessageSquare, color: "emerald" },
  ];

  return (
    <div className="p-8 max-w-6xl animate-fade-in">
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
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4 mb-10">
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
      <nav className="absolute top-0 left-0 right-0 flex items-center justify-between px-8 py-5 z-10">
        <span className="font-display text-xl font-700 gradient-text">PageFlow</span>
        <div className="flex items-center gap-4">
          <Link href="/pricing" className="text-sm text-zinc-400 hover:text-white transition-colors">
            Pricing
          </Link>
          <Link
            href="/auth"
            className="px-4 py-2 glass border border-white/10 hover:bg-white/8 text-zinc-300 text-sm font-semibold rounded-xl transition-all"
          >
            Sign in
          </Link>
          <Link
            href="/auth"
            className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold rounded-xl transition-all glow-sm"
          >
            Get started free
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
            { value: "৳799",  label: "Pro plan/month" },
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
// lib/plans.ts
// Single source of truth for all subscription plans and their limits.
// Used by: pricing page, billing page, API limit checks, middleware.

export type PlanId = "free" | "pro" | "business";

export type Plan = {
  id:            PlanId;
  name:          string;
  price:         number;      // BDT per month
  priceUSD:      number;      // USD per month (for reference)
  pages:         number;      // max connected pages (-1 = unlimited)
  automations:   number;      // max automation rules per page (-1 = unlimited)
  aiReplies:     number;      // max AI replies per month (-1 = unlimited)
  leads:         number;      // max leads stored (-1 = unlimited)
  features:      string[];
  highlighted:   boolean;     // show as "most popular"
  badge?:        string;
};

export const PLANS: Record<PlanId, Plan> = {
  free: {
    id:          "free",
    name:        "Free",
    price:       0,
    priceUSD:    0,
    pages:       1,
    automations: 3,
    aiReplies:   0,
    leads:       50,
    highlighted: false,
    features: [
      "1 Facebook page",
      "3 automation rules",
      "50 leads stored",
      "Basic dashboard",
      "Email support",
    ],
  },

  pro: {
    id:          "pro",
    name:        "Pro",
    price:       799,
    priceUSD:    7,
    pages:       5,
    automations: 25,
    aiReplies:   500,
    leads:       1000,
    highlighted: true,
    badge:       "Most Popular",
    features: [
      "5 Facebook pages",
      "25 automation rules",
      "500 AI replies/month",
      "1,000 leads stored",
      "Bangla + English AI",
      "Priority support",
      "Analytics dashboard",
    ],
  },

  business: {
    id:          "business",
    name:        "Business",
    price:       1999,
    priceUSD:    18,
    pages:       -1,
    automations: -1,
    aiReplies:   -1,
    leads:       -1,
    highlighted: false,
    badge:       "Best Value",
    features: [
      "Unlimited pages",
      "Unlimited automations",
      "Unlimited AI replies",
      "Unlimited leads",
      "Custom AI persona",
      "Webhook integrations",
      "Dedicated support",
      "White-label ready",
    ],
  },
};

export const PLAN_LIST = Object.values(PLANS);

// ─── Limit checkers ───────────────────────────────────────────────────────────

export function canAddPage(plan: PlanId, currentPages: number): boolean {
  const limit = PLANS[plan].pages;
  return limit === -1 || currentPages < limit;
}

export function canAddAutomation(plan: PlanId, currentRules: number): boolean {
  const limit = PLANS[plan].automations;
  return limit === -1 || currentRules < limit;
}

export function canUseAI(plan: PlanId): boolean {
  return PLANS[plan].aiReplies !== 0;
}

export function canAddLead(plan: PlanId, currentLeads: number): boolean {
  const limit = PLANS[plan].leads;
  return limit === -1 || currentLeads < limit;
}

export function formatLimit(value: number): string {
  return value === -1 ? "Unlimited" : value.toLocaleString();
}

'@ | Set-Content -Path '.\lib\plans.ts' -Encoding UTF8

@'
import type { SupabaseClient } from "@supabase/supabase-js";
import type { PlanId } from "@/lib/plans";
import type { ServiceResult } from "./pages.service";

// ─── Types ────────────────────────────────────────────────────────────────────

export type Subscription = {
  id:                string;
  user_id:           string;
  plan:              PlanId;
  status:            "active" | "cancelled" | "expired" | "trialing";
  payment_method:    string | null;
  transaction_id:    string | null;
  amount:            number;
  currency:          string;
  current_period_start: string;
  current_period_end:   string;
  cancel_at_period_end: boolean;
  created_at:        string;
  updated_at:        string;
};

export type UsageStats = {
  pages:       number;
  automations: number;
  leads:       number;
  ai_replies:  number;
};

const SUB_COLUMNS = "id, user_id, plan, status, payment_method, transaction_id, amount, currency, current_period_start, current_period_end, cancel_at_period_end, created_at, updated_at";

// ─── Service ──────────────────────────────────────────────────────────────────

export const SubscriptionService = {
  // GET active subscription for user
  async get(
    supabase: SupabaseClient,
    userId: string
  ): Promise<ServiceResult<Subscription | null>> {
    const { data, error } = await supabase
      .from("subscriptions")
      .select(SUB_COLUMNS)
      .eq("user_id", userId)
      .in("status", ["active", "trialing"])
      .order("created_at", { ascending: false })
      .maybeSingle();

    if (error) {
      console.error("[SubscriptionService.get]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // GET all subscription history
  async getHistory(
    supabase: SupabaseClient,
    userId: string
  ): Promise<ServiceResult<Subscription[]>> {
    const { data, error } = await supabase
      .from("subscriptions")
      .select(SUB_COLUMNS)
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("[SubscriptionService.getHistory]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data: data ?? [], error: null };
  },

  // CREATE subscription after successful payment
  async create(
    supabase: SupabaseClient,
    userId: string,
    input: {
      plan:           PlanId;
      transaction_id: string;
      amount:         number;
      payment_method: string;
    }
  ): Promise<ServiceResult<Subscription>> {
    const now   = new Date();
    const end   = new Date(now);
    end.setMonth(end.getMonth() + 1);

    // Cancel any existing active subscriptions first
    await supabase
      .from("subscriptions")
      .update({ status: "cancelled", updated_at: now.toISOString() })
      .eq("user_id", userId)
      .in("status", ["active", "trialing"]);

    const { data, error } = await supabase
      .from("subscriptions")
      .insert({
        user_id:               userId,
        plan:                  input.plan,
        status:                "active",
        payment_method:        input.payment_method,
        transaction_id:        input.transaction_id,
        amount:                input.amount,
        currency:              "BDT",
        current_period_start:  now.toISOString(),
        current_period_end:    end.toISOString(),
        cancel_at_period_end:  false,
        updated_at:            now.toISOString(),
      })
      .select(SUB_COLUMNS)
      .single();

    if (error) {
      console.error("[SubscriptionService.create]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // GET current usage stats for a user
  async getUsage(
    supabase: SupabaseClient,
    userId: string
  ): Promise<ServiceResult<UsageStats>> {
    const [pagesRes, leadsRes] = await Promise.all([
      supabase
        .from("pages")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId),
      supabase
        .from("leads")
        .select("id", { count: "exact", head: true })
        .in(
          "page_id",
          (
            await supabase
              .from("pages")
              .select("id")
              .eq("user_id", userId)
          ).data?.map((p: { id: string }) => p.id) ?? []
        ),
    ]);

    return {
      data: {
        pages:       pagesRes.count      ?? 0,
        automations: 0,                        // computed per page when needed
        leads:       leadsRes.count      ?? 0,
        ai_replies:  0,                        // tracked separately in future
      },
      error: null,
    };
  },

  // GET plan for user (defaults to "free" if no active subscription)
  async getUserPlan(
    supabase: SupabaseClient,
    userId: string
  ): Promise<PlanId> {
    const { data } = await SubscriptionService.get(supabase, userId);
    return data?.plan ?? "free";
  },
};

'@ | Set-Content -Path '.\lib\db\subscription.service.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { requireAuth, ApiError } from "@/lib/server-auth";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS } from "@/lib/plans";

/**
 * GET /api/subscription
 * Returns current subscription, plan details, and usage stats.
 */
export async function GET() {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    const [subResult, usageResult, historyResult] = await Promise.all([
      SubscriptionService.get(supabase, user.id),
      SubscriptionService.getUsage(supabase, user.id),
      SubscriptionService.getHistory(supabase, user.id),
    ]);

    const plan   = subResult.data?.plan ?? "free";
    const planDetails = PLANS[plan];

    return NextResponse.json({
      subscription: subResult.data,
      plan:         planDetails,
      usage:        usageResult.data,
      history:      historyResult.data ?? [],
      isFreePlan:   plan === "free",
    });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/subscription]", err);
    return ApiError.internal();
  }
}

'@ | Set-Content -Path '.\app\api\subscription\route.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { PLANS, type PlanId } from "@/lib/plans";

/**
 * POST /api/payment/sslcommerz
 * Initiates a payment session with SSLCommerz.
 * Body: { plan_id: "pro" | "business" }
 *
 * SSLCommerz flow:
 * 1. Client calls this endpoint
 * 2. We call SSLCommerz API to create a session
 * 3. Return the payment URL
 * 4. Client redirects to SSLCommerz payment page
 * 5. SSLCommerz redirects back to /api/payment/verify
 */
export async function POST(request: Request) {
  try {
    const { user } = await requireAuth().catch((r) => { throw r; });

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const planId = sanitizeString(body.plan_id) as PlanId | null;
    if (!planId || !["pro", "business"].includes(planId)) {
      return ApiError.badRequest("plan_id must be ''pro'' or ''business''");
    }

    const plan = PLANS[planId];
    const storeId  = process.env.SSLCOMMERZ_STORE_ID;
    const storePass = process.env.SSLCOMMERZ_STORE_PASSWORD;
    const isSandbox = process.env.SSLCOMMERZ_SANDBOX === "true";

    if (!storeId || !storePass) {
      // Return mock response in development
      console.warn("[SSLCommerz] Credentials not set — returning mock payment URL");
      return NextResponse.json({
        success:     true,
        paymentUrl:  `${process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000"}/dashboard/billing?mock=true&plan=${planId}`,
        mock:        true,
        message:     "Add SSLCOMMERZ_STORE_ID and SSLCOMMERZ_STORE_PASSWORD to .env.local for real payments",
      });
    }

    const transactionId = `PF-${Date.now()}-${user.id.slice(0, 8)}`;
    const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

    const params = new URLSearchParams({
      store_id:          storeId,
      store_passwd:      storePass,
      total_amount:      plan.price.toString(),
      currency:          "BDT",
      tran_id:           transactionId,
      success_url:       `${baseUrl}/api/payment/verify?status=success&tran_id=${transactionId}&plan=${planId}&user_id=${user.id}`,
      fail_url:          `${baseUrl}/api/payment/verify?status=fail`,
      cancel_url:        `${baseUrl}/dashboard/billing?cancelled=true`,
      ipn_url:           `${baseUrl}/api/payment/verify`,
      product_name:      `PageFlow ${plan.name} Plan`,
      product_category:  "SaaS Subscription",
      product_profile:   "non-physical-goods",
      cus_name:          user.email?.split("@")[0] ?? "Customer",
      cus_email:         user.email ?? "",
      cus_phone:         "01XXXXXXXXX",
      cus_add1:          "Dhaka",
      cus_city:          "Dhaka",
      cus_country:       "Bangladesh",
      shipping_method:   "NO",
      num_of_item:       "1",
      weight_of_items:   "0",
      amount_per_item:   plan.price.toString(),
    });

    const apiUrl = isSandbox
      ? "https://sandbox.sslcommerz.com/gwprocess/v4/api.php"
      : "https://securepay.sslcommerz.com/gwprocess/v4/api.php";

    const response = await fetch(apiUrl, {
      method:  "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:    params.toString(),
    });

    const data = await response.json() as {
      status: string;
      GatewayPageURL?: string;
      failedreason?: string;
    };

    if (data.status !== "SUCCESS" || !data.GatewayPageURL) {
      console.error("[SSLCommerz] Init failed:", data.failedreason);
      return ApiError.internal(data.failedreason ?? "Payment initialization failed");
    }

    return NextResponse.json({
      success:    true,
      paymentUrl: data.GatewayPageURL,
      tran_id:    transactionId,
    });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/payment/sslcommerz]", err);
    return ApiError.internal();
  }
}

'@ | Set-Content -Path '.\app\api\payment\sslcommerz\route.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { getSupabaseServer } from "@/lib/server-auth";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS, type PlanId } from "@/lib/plans";

/**
 * GET /api/payment/verify
 * Called by SSLCommerz as success/fail/cancel redirect.
 * Also handles IPN (Instant Payment Notification) via POST.
 */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const status  = searchParams.get("status");
  const tranId  = searchParams.get("tran_id");
  const planId  = searchParams.get("plan") as PlanId | null;
  const userId  = searchParams.get("user_id");
  const isMock  = searchParams.get("mock") === "true";

  const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

  if (status !== "success" || !tranId || !planId || !userId) {
    return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=failed`);
  }

  try {
    const supabase = await getSupabaseServer();
    const plan     = PLANS[planId];

    if (!plan || planId === "free") {
      return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=invalid`);
    }

    // For mock payments (dev mode) — skip SSLCommerz verification
    if (!isMock) {
      const storeId   = process.env.SSLCOMMERZ_STORE_ID;
      const storePass = process.env.SSLCOMMERZ_STORE_PASSWORD;
      const isSandbox = process.env.SSLCOMMERZ_SANDBOX === "true";

      if (storeId && storePass) {
        // Verify transaction with SSLCommerz
        const verifyUrl = isSandbox
          ? `https://sandbox.sslcommerz.com/validator/api/validationserverAPI.php`
          : `https://securepay.sslcommerz.com/validator/api/validationserverAPI.php`;

        const verifyRes = await fetch(
          `${verifyUrl}?val_id=${tranId}&store_id=${storeId}&store_passwd=${storePass}&format=json`
        );
        const verifyData = await verifyRes.json() as {
          status: string;
          amount: string;
          currency_type: string;
        };

        if (verifyData.status !== "VALID" && verifyData.status !== "VALIDATED") {
          console.error("[Verify] Invalid transaction:", tranId);
          return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=invalid`);
        }
      }
    }

    // Create subscription in DB
    const { error } = await SubscriptionService.create(supabase, userId, {
      plan:           planId,
      transaction_id: tranId,
      amount:         plan.price,
      payment_method: isMock ? "mock" : "sslcommerz",
    });

    if (error) {
      console.error("[Verify] Subscription create failed:", error.message);
      return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=error`);
    }

    return NextResponse.redirect(
      `${baseUrl}/dashboard/billing?payment=success&plan=${planId}`
    );
  } catch (err) {
    console.error("[GET /api/payment/verify]", err);
    return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=error`);
  }
}

/**
 * POST /api/payment/verify
 * IPN handler — SSLCommerz calls this server-to-server to confirm payment.
 */
export async function POST(request: Request) {
  try {
    const body = await request.formData();
    const status  = body.get("status")?.toString();
    const tranId  = body.get("tran_id")?.toString();
    const amount  = body.get("amount")?.toString();
    const valId   = body.get("val_id")?.toString();

    console.log("[IPN] Received:", { status, tranId, amount, valId });

    // TODO: Validate IPN signature and update subscription status
    // This is called server-to-server, not by the user

    return NextResponse.json({ status: "ok" });
  } catch (err) {
    console.error("[POST /api/payment/verify]", err);
    return NextResponse.json({ status: "error" });
  }
}

'@ | Set-Content -Path '.\app\api\payment\verify\route.ts' -Encoding UTF8

@'
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
                      <span className="text-zinc-500 text-sm mt-1">৳</span>
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
                    { label: "Pages",       value: plan.pages       === -1 ? "∞" : plan.pages },
                    { label: "Rules",       value: plan.automations === -1 ? "∞" : plan.automations },
                    { label: "AI Replies",  value: plan.aiReplies   === 0  ? "None" : plan.aiReplies === -1 ? "∞" : plan.aiReplies + "/mo" },
                    { label: "Leads",       value: plan.leads       === -1 ? "∞" : plan.leads },
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

'@ | Set-Content -Path '.\app\pricing\page.tsx' -Encoding UTF8

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
      <div className="p-8 max-w-4xl animate-fade-in space-y-4">
        <div className="h-8 bg-white/5 rounded w-40 animate-pulse" />
        <div className="h-40 glass rounded-2xl animate-pulse" />
        <div className="h-32 glass rounded-2xl animate-pulse" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-4xl animate-fade-in">
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
                    : `৳${data?.plan?.price?.toLocaleString()}/month`}
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
                        <p className="text-zinc-500 text-xs">৳{plan.price.toLocaleString()}/mo</p>
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
                      ৳{sub.amount.toLocaleString()}
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
"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase";
import {
  LayoutDashboard, FileText, Zap, BrainCircuit,
  Users, LogOut, ChevronRight, Sparkles, CreditCard,
} from "lucide-react";

// Singleton — same session as the rest of the app.
const supabase = createClient();

const navItems = [
  { href: "/dashboard",             label: "Dashboard",   icon: LayoutDashboard },
  { href: "/dashboard/pages",       label: "Pages",       icon: FileText },
  { href: "/dashboard/automation",  label: "Automation",  icon: Zap },
  { href: "/dashboard/ai-settings", label: "AI Settings", icon: BrainCircuit },
  { href: "/dashboard/leads",       label: "Leads",       icon: Users },
  { href: "/dashboard/billing",     label: "Billing",     icon: CreditCard },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router   = useRouter();

  async function handleSignOut() {
    await supabase.auth.signOut();
    router.push("/auth");
    router.refresh();
  }

  return (
    <aside
      className="fixed left-0 top-0 h-screen w-60 flex flex-col z-40 border-r border-white/5"
      style={{ background: "linear-gradient(180deg, #0d0d14 0%, #0a0a10 100%)" }}
    >
      {/* Logo */}
      <div className="px-5 pt-6 pb-5 border-b border-white/5">
        <Link href="/dashboard" className="flex items-center gap-2.5">
          <div className="w-7 h-7 rounded-lg bg-indigo-600 flex items-center justify-center glow-sm">
            <Sparkles size={14} className="text-white" />
          </div>
          <span className="font-display text-lg font-700 text-white tracking-tight">PageFlow</span>
        </Link>
        <div className="mt-3 flex items-center gap-2 px-2.5 py-1.5 rounded-lg bg-indigo-600/10 border border-indigo-500/20">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 relative">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
          </span>
          <span className="text-xs text-indigo-300 font-medium">Pro workspace</span>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 py-4 px-3 space-y-0.5 overflow-y-auto">
        <p className="px-3 py-2 text-[10px] font-semibold uppercase tracking-widest text-zinc-600">
          Navigation
        </p>
        {navItems.map(({ href, label, icon: Icon }) => {
          const isActive =
            href === "/dashboard" ? pathname === href : pathname.startsWith(href);

          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150 group relative ${
                isActive
                  ? "nav-active text-indigo-300"
                  : "text-zinc-500 hover:text-zinc-300 hover:bg-white/4"
              }`}
            >
              <Icon
                size={16}
                className={`flex-shrink-0 transition-colors ${
                  isActive ? "text-indigo-400" : "text-zinc-600 group-hover:text-zinc-400"
                }`}
              />
              {label}
              {isActive && (
                <ChevronRight size={12} className="ml-auto text-indigo-500" />
              )}
            </Link>
          );
        })}
      </nav>

      {/* Bottom */}
      <div className="px-3 pb-5 pt-3 border-t border-white/5 space-y-1">
        <button
          onClick={handleSignOut}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-zinc-600 hover:text-red-400 hover:bg-red-500/8 transition-all duration-150"
        >
          <LogOut size={16} />
          Sign out
        </button>
        <div className="px-3 pt-2">
          <p className="text-[10px] text-zinc-700">© 2025 PageFlow Inc.</p>
        </div>
      </div>
    </aside>
  );
}

'@ | Set-Content -Path '.\components\Sidebar.tsx' -Encoding UTF8
