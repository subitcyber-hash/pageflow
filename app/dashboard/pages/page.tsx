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