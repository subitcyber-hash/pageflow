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
              placeholder='e.g. price, দাম, how much, shipping'
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
              placeholder={'e.g. আমাদের পণ্যের দাম ৫০০৳ থেকে শুরু। বিস্তারিত জানতে inbox করুন! 😊'}
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