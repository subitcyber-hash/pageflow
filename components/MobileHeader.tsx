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