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