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