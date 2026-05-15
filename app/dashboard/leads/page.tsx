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