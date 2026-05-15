# PWA setup script
$OutputEncoding = [System.Text.Encoding]::UTF8

New-Item -ItemType Directory -Force -Path ".\app" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard" | Out-Null
New-Item -ItemType Directory -Force -Path ".\components" | Out-Null

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
