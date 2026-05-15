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