"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase";
import {
  LayoutDashboard, FileText, Zap, BrainCircuit,
  Users, LogOut, ChevronRight, Sparkles, CreditCard,
} from "lucide-react";

// Singleton â€” same session as the rest of the app.
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
          <p className="text-[10px] text-zinc-700">Â© 2025 PageFlow Inc.</p>
        </div>
      </div>
    </aside>
  );
}

