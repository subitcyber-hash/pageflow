# Phase 3 setup script
# Run from your project root: .\setup-phase3.ps1

New-Item -ItemType Directory -Force -Path ".\app" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\ai-reply" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\ai-settings" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard\ai-settings" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib\ai" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib\db" | Out-Null

@'
/**
 * lib/ai/groq.ts
 * Groq AI integration for smart reply generation.
 * Supports Bangla + English, multiple tones.
 */

// ─── Types ────────────────────────────────────────────────────────────────────

export type GenerateReplyInput = {
  userMessage:   string;
  businessName?: string;
  businessInfo?: string;  // e.g. "We sell clothes. Prices start at 500tk"
  persona?:      string;  // custom opening greeting
  language?:     "bangla" | "english" | "mixed";
  tone?:         "friendly" | "professional" | "casual";
  maxTokens?:    number;
};

export type GenerateReplyResult =
  | { reply: string; error: null;   tokensUsed: number }
  | { reply: null;   error: string; tokensUsed: 0 };

// ─── Client ───────────────────────────────────────────────────────────────────

function getGroqApiKey(): string {
  const key = process.env.GROQ_API_KEY;
  if (!key) throw new Error("GROQ_API_KEY is not set in environment variables");
  return key;
}

// ─── Main function ────────────────────────────────────────────────────────────

export async function generateReply(
  input: GenerateReplyInput
): Promise<GenerateReplyResult> {
  try {
    const apiKey = getGroqApiKey();

    const languageInstruction =
      input.language === "bangla"
        ? "Always reply in Bangla (Bengali script). Use natural conversational Bangla."
        : input.language === "mixed"
        ? "Reply in a mix of Bangla and English (Banglish style), natural for Bangladeshi users."
        : "Reply in English.";

    const toneInstruction =
      input.tone === "professional"
        ? "Use a professional and formal tone."
        : input.tone === "casual"
        ? "Use a casual, relaxed tone like talking to a friend."
        : "Use a friendly, warm, and helpful tone. Use emojis occasionally.";

    const systemPrompt = [
      `You are a customer service assistant for a Facebook business page.`,
      input.businessName
        ? `Business name: ${input.businessName}`
        : "",
      input.businessInfo
        ? `Business info: ${input.businessInfo}`
        : "",
      languageInstruction,
      toneInstruction,
      `Keep replies concise (2-4 sentences max).`,
      `Do not use markdown formatting.`,
      `If you don''t know something specific, offer to help or ask the customer to inbox for details.`,
    ]
      .filter(Boolean)
      .join("\n");

    const response = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model:       "llama3-8b-8192",
          max_tokens:  input.maxTokens ?? 300,
          temperature: 0.7,
          messages: [
            { role: "system", content: systemPrompt          },
            { role: "user",   content: input.userMessage     },
          ],
        }),
      }
    );

    if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      const errMsg = (errData as { error?: { message?: string } })?.error?.message ?? `Groq API error: ${response.status}`;
      console.error("[Groq] API error:", errMsg);
      return { reply: null, error: errMsg, tokensUsed: 0 };
    }

    const data = await response.json() as {
      choices: { message: { content: string } }[];
      usage:   { total_tokens: number };
    };

    const reply = data.choices?.[0]?.message?.content?.trim();
    if (!reply) {
      return { reply: null, error: "Empty response from Groq", tokensUsed: 0 };
    }

    return {
      reply,
      error:      null,
      tokensUsed: data.usage?.total_tokens ?? 0,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown AI error";
    console.error("[Groq] generateReply error:", message);
    return { reply: null, error: message, tokensUsed: 0 };
  }
}

// ─── Test reply (used when GROQ_API_KEY not set) ──────────────────────────────

export function getFallbackReply(language: string = "english"): string {
  if (language === "bangla" || language === "mixed") {
    return "ধন্যবাদ আপনার মেসেজের জন্য! আমরা শীঘ্রই আপনার সাথে যোগাযোগ করব। 😊";
  }
  return "Thank you for your message! We will get back to you shortly. 😊";
}

'@ | Set-Content -Path '.\lib\ai\groq.ts' -Encoding UTF8

@'
import type { SupabaseClient } from "@supabase/supabase-js";
import type { ServiceResult } from "./pages.service";

// ─── Types ────────────────────────────────────────────────────────────────────

export type AISettings = {
  id:            string;
  user_id:       string;
  page_id:       string | null;
  enabled:       boolean;
  tone:          "friendly" | "professional" | "casual";
  language:      "bangla" | "english" | "mixed";
  persona:       string;
  business_name: string;
  business_info: string;
  max_replies:   number;
  confidence:    number;
  escalate:      boolean;
  created_at:    string;
  updated_at:    string;
};

export type UpsertAISettingsInput = {
  page_id?:       string | null;
  enabled?:       boolean;
  tone?:          "friendly" | "professional" | "casual";
  language?:      "bangla" | "english" | "mixed";
  persona?:       string;
  business_name?: string;
  business_info?: string;
  max_replies?:   number;
  confidence?:    number;
  escalate?:      boolean;
};

const COLUMNS = "id, user_id, page_id, enabled, tone, language, persona, business_name, business_info, max_replies, confidence, escalate, created_at, updated_at";

// ─── Service ──────────────────────────────────────────────────────────────────

export const AISettingsService = {
  // GET settings for user (optionally scoped to a page)
  async get(
    supabase: SupabaseClient,
    userId: string,
    pageId?: string | null
  ): Promise<ServiceResult<AISettings | null>> {
    let query = supabase
      .from("ai_settings")
      .select(COLUMNS)
      .eq("user_id", userId);

    if (pageId) {
      query = query.eq("page_id", pageId);
    } else {
      query = query.is("page_id", null);
    }

    const { data, error } = await query.maybeSingle();

    if (error) {
      console.error("[AISettingsService.get]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // UPSERT (create or update) AI settings
  async upsert(
    supabase: SupabaseClient,
    userId: string,
    input: UpsertAISettingsInput
  ): Promise<ServiceResult<AISettings>> {
    const { data, error } = await supabase
      .from("ai_settings")
      .upsert(
        {
          user_id:       userId,
          page_id:       input.page_id ?? null,
          enabled:       input.enabled       ?? true,
          tone:          input.tone          ?? "friendly",
          language:      input.language      ?? "bangla",
          persona:       input.persona       ?? "",
          business_name: input.business_name ?? "",
          business_info: input.business_info ?? "",
          max_replies:   input.max_replies   ?? 5,
          confidence:    input.confidence    ?? 75,
          escalate:      input.escalate      ?? true,
          updated_at:    new Date().toISOString(),
        },
        {
          onConflict:    "user_id,page_id",
          ignoreDuplicates: false,
        }
      )
      .select(COLUMNS)
      .single();

    if (error) {
      console.error("[AISettingsService.upsert]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },
};

'@ | Set-Content -Path '.\lib\db\ai-settings.service.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { AISettingsService } from "@/lib/db/ai-settings.service";

const VALID_TONES     = ["friendly", "professional", "casual"] as const;
const VALID_LANGUAGES = ["bangla", "english", "mixed"] as const;

/**
 * GET /api/ai-settings?page_id=<uuid>
 * Returns AI settings for user (global or page-specific).
 */
export async function GET(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    const { searchParams } = new URL(request.url);
    const pageId = searchParams.get("page_id");

    const { data, error } = await AISettingsService.get(supabase, user.id, pageId);

    if (error) return ApiError.internal(error.message);

    // Return defaults if no settings saved yet
    if (!data) {
      return NextResponse.json({
        settings: {
          enabled:       true,
          tone:          "friendly",
          language:      "bangla",
          persona:       "আমাদের পেজে স্বাগতম! আমি কীভাবে আপনাকে সাহায্য করতে পারি?",
          business_name: "",
          business_info: "",
          max_replies:   5,
          confidence:    75,
          escalate:      true,
        },
        isDefault: true,
      });
    }

    return NextResponse.json({ settings: data, isDefault: false });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/ai-settings]", err);
    return ApiError.internal();
  }
}

/**
 * POST /api/ai-settings
 * Save or update AI settings.
 */
export async function POST(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    // Validate tone
    if (body.tone !== undefined &&
        !VALID_TONES.includes(body.tone as typeof VALID_TONES[number])) {
      return ApiError.badRequest(`tone must be one of: ${VALID_TONES.join(", ")}`);
    }

    // Validate language
    if (body.language !== undefined &&
        !VALID_LANGUAGES.includes(body.language as typeof VALID_LANGUAGES[number])) {
      return ApiError.badRequest(`language must be one of: ${VALID_LANGUAGES.join(", ")}`);
    }

    // Validate confidence
    if (body.confidence !== undefined) {
      const c = Number(body.confidence);
      if (isNaN(c) || c < 0 || c > 100) {
        return ApiError.badRequest("confidence must be between 0 and 100");
      }
    }

    // Validate max_replies
    if (body.max_replies !== undefined) {
      const m = Number(body.max_replies);
      if (isNaN(m) || m < 1 || m > 100) {
        return ApiError.badRequest("max_replies must be between 1 and 100");
      }
    }

    const { data, error } = await AISettingsService.upsert(supabase, user.id, {
      page_id:       (body.page_id as string) ?? null,
      enabled:       typeof body.enabled  === "boolean" ? body.enabled  : undefined,
      escalate:      typeof body.escalate === "boolean" ? body.escalate : undefined,
      tone:          body.tone      as typeof VALID_TONES[number]     | undefined,
      language:      body.language  as typeof VALID_LANGUAGES[number] | undefined,
      persona:       sanitizeString(body.persona,       1000) ?? undefined,
      business_name: sanitizeString(body.business_name, 255)  ?? undefined,
      business_info: sanitizeString(body.business_info, 2000) ?? undefined,
      max_replies:   body.max_replies !== undefined ? Number(body.max_replies) : undefined,
      confidence:    body.confidence  !== undefined ? Number(body.confidence)  : undefined,
    });

    if (error) return ApiError.internal(error.message);

    return NextResponse.json({ settings: data });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/ai-settings]", err);
    return ApiError.internal();
  }
}

'@ | Set-Content -Path '.\app\api\ai-settings\route.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { generateReply, getFallbackReply } from "@/lib/ai/groq";
import { AISettingsService } from "@/lib/db/ai-settings.service";

/**
 * POST /api/ai-reply
 * Generate an AI reply for a given message.
 * Used for testing from AI Settings page + future webhook handler.
 * Body: { message: string, page_id?: string }
 */
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
    if (!message) {
      return ApiError.badRequest("''message'' is required");
    }

    const pageId = body.page_id as string | undefined;

    // Load user''s AI settings
    const { data: settings } = await AISettingsService.get(
      supabase,
      user.id,
      pageId ?? null
    );

    // Check if AI is enabled
    if (settings && !settings.enabled) {
      return NextResponse.json({
        reply:   getFallbackReply(settings.language),
        source:  "fallback",
        reason:  "AI disabled",
      });
    }

    // Check if API key exists
    if (!process.env.GROQ_API_KEY) {
      return NextResponse.json(
        {
          error:  "GROQ_API_KEY not configured",
          code:   "NO_API_KEY",
          hint:   "Add GROQ_API_KEY to your .env.local file",
        },
        { status: 503 }
      );
    }

    // Generate AI reply
    const result = await generateReply({
      userMessage:   message,
      businessName:  settings?.business_name || undefined,
      businessInfo:  settings?.business_info || undefined,
      persona:       settings?.persona       || undefined,
      language:      settings?.language      ?? "bangla",
      tone:          settings?.tone          ?? "friendly",
      maxTokens:     300,
    });

    if (result.error) {
      return NextResponse.json(
        { error: result.error, code: "AI_ERROR" },
        { status: 500 }
      );
    }

    return NextResponse.json({
      reply:      result.reply,
      source:     "groq",
      tokensUsed: result.tokensUsed,
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
"use client";

import { useState, useEffect, useCallback } from "react";
import {
  BrainCircuit, Save, RotateCcw, Sparkles, Shield,
  Globe, Loader2, SendHorizonal, CheckCircle2, AlertCircle,
  ChevronDown,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Settings = {
  enabled:       boolean;
  tone:          "friendly" | "professional" | "casual";
  language:      "bangla" | "english" | "mixed";
  persona:       string;
  business_name: string;
  business_info: string;
  max_replies:   number;
  confidence:    number;
  escalate:      boolean;
};

type Page = { id: string; name: string };

const DEFAULTS: Settings = {
  enabled:       true,
  tone:          "friendly",
  language:      "bangla",
  persona:       "আমাদের পেজে স্বাগতম! আমি কীভাবে আপনাকে সাহায্য করতে পারি?",
  business_name: "",
  business_info: "",
  max_replies:   5,
  confidence:    75,
  escalate:      true,
};

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function AISettingsPage() {
  const [settings,    setSettings]    = useState<Settings>(DEFAULTS);
  const [pages,       setPages]       = useState<Page[]>([]);
  const [pageId,      setPageId]      = useState<string>("global");
  const [loading,     setLoading]     = useState(true);
  const [saving,      setSaving]      = useState(false);
  const [saveStatus,  setSaveStatus]  = useState<"idle" | "saved" | "error">("idle");
  const [fetchError,  setFetchError]  = useState<string | null>(null);

  // Test AI
  const [testMsg,     setTestMsg]     = useState("");
  const [testResult,  setTestResult]  = useState<string | null>(null);
  const [testError,   setTestError]   = useState<string | null>(null);
  const [testing,     setTesting]     = useState(false);

  // Load pages
  useEffect(() => {
    fetch("/api/pages", { credentials: "include" })
      .then((r) => r.json())
      .then((d) => setPages(d.pages ?? []))
      .catch(() => {});
  }, []);

  // Load settings when page selection changes
  const loadSettings = useCallback(async () => {
    setLoading(true);
    setFetchError(null);
    try {
      const url = pageId !== "global"
        ? `/api/ai-settings?page_id=${pageId}`
        : "/api/ai-settings";
      const res  = await fetch(url, { credentials: "include" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setSettings({ ...DEFAULTS, ...data.settings });
    } catch (e: unknown) {
      setFetchError(e instanceof Error ? e.message : "Failed to load settings.");
    } finally {
      setLoading(false);
    }
  }, [pageId]);

  useEffect(() => { loadSettings(); }, [loadSettings]);

  function update<K extends keyof Settings>(key: K, value: Settings[K]) {
    setSettings((prev) => ({ ...prev, [key]: value }));
    setSaveStatus("idle");
  }

  async function handleSave() {
    setSaving(true);
    setSaveStatus("idle");
    try {
      const res = await fetch("/api/ai-settings", {
        method:      "POST",
        credentials: "include",
        headers:     { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...settings,
          page_id: pageId !== "global" ? pageId : null,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setSaveStatus("saved");
      setTimeout(() => setSaveStatus("idle"), 3000);
    } catch {
      setSaveStatus("error");
    } finally {
      setSaving(false);
    }
  }

  async function handleTest() {
    if (!testMsg.trim()) return;
    setTesting(true);
    setTestResult(null);
    setTestError(null);
    try {
      const res = await fetch("/api/ai-reply", {
        method:      "POST",
        credentials: "include",
        headers:     { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: testMsg.trim(),
          page_id: pageId !== "global" ? pageId : undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        if (data.code === "NO_API_KEY") {
          setTestError("⚠ GROQ_API_KEY not set. Add it to your .env.local file.");
        } else {
          setTestError(data.error ?? "AI error");
        }
      } else {
        setTestResult(data.reply);
      }
    } catch {
      setTestError("Network error. Please try again.");
    } finally {
      setTesting(false);
    }
  }

  if (loading) {
    return (
      <div className="p-8 max-w-3xl animate-fade-in">
        <div className="mb-8">
          <div className="h-4 bg-white/5 rounded w-24 mb-3 animate-pulse" />
          <div className="h-8 bg-white/8 rounded w-48 mb-2 animate-pulse" />
          <div className="h-3 bg-white/5 rounded w-64 animate-pulse" />
        </div>
        <div className="space-y-4">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="glass rounded-2xl p-6 animate-pulse h-36" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="p-8 max-w-3xl animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between mb-8 gap-4 flex-wrap">
        <div>
          <p className="text-xs uppercase tracking-widest text-zinc-600 mb-1">Configuration</p>
          <h1 className="font-display text-3xl font-700 text-white">AI Settings</h1>
          <p className="text-zinc-500 text-sm mt-1">
            Configure how AI replies to your customers automatically.
          </p>
        </div>
        {/* Page selector */}
        <div className="relative">
          <select
            value={pageId}
            onChange={(e) => setPageId(e.target.value)}
            className="bg-white/5 border border-white/8 rounded-xl px-4 py-2.5 pr-9 text-sm text-zinc-300 focus:outline-none focus:border-indigo-500 transition-all appearance-none"
          >
            <option value="global">Global (All Pages)</option>
            {pages.map((p) => (
              <option key={p.id} value={p.id}>{p.name}</option>
            ))}
          </select>
          <ChevronDown size={13} className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-600 pointer-events-none" />
        </div>
      </div>

      {fetchError && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
          <span>⚠</span><span>{fetchError}</span>
        </div>
      )}

      <div className="space-y-5">

        {/* ── AI Enable Toggle ── */}
        <div className="glass rounded-2xl p-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-xl bg-indigo-600/15 border border-indigo-500/20 text-indigo-300">
              <BrainCircuit size={16} />
            </div>
            <div>
              <p className="font-semibold text-white text-sm">AI Auto Reply</p>
              <p className="text-xs text-zinc-600 mt-0.5">
                {settings.enabled ? "AI is active — replying to messages" : "AI is paused — not replying"}
              </p>
            </div>
          </div>
          <button
            onClick={() => update("enabled", !settings.enabled)}
            className={`w-11 h-6 rounded-full relative transition-all duration-200 ${
              settings.enabled ? "bg-indigo-600" : "bg-zinc-700"
            }`}
          >
            <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow transition-all duration-200 ${
              settings.enabled ? "left-5" : "left-0.5"
            }`} />
          </button>
        </div>

        {/* ── Business Info ── */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="p-2.5 rounded-xl bg-emerald-600/15 border border-emerald-500/20 text-emerald-300">
              <Sparkles size={16} />
            </div>
            <div>
              <h2 className="font-semibold text-white text-sm">Business Information</h2>
              <p className="text-xs text-zinc-600 mt-0.5">AI uses this to generate accurate replies</p>
            </div>
          </div>
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                Business Name
              </label>
              <input
                type="text"
                value={settings.business_name}
                onChange={(e) => update("business_name", e.target.value)}
                placeholder="e.g. Dhaka Fashion House"
                className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                Business Description
              </label>
              <textarea
                value={settings.business_info}
                onChange={(e) => update("business_info", e.target.value)}
                placeholder={"e.g. আমরা মহিলাদের পোশাক বিক্রি করি। দাম ৫০০-২০০০৳। ডেলিভারি সারা বাংলাদেশে।"}
                rows={3}
                className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all resize-none"
              />
              <p className="text-[11px] text-zinc-700 mt-1.5">
                The more detail you add, the better AI replies will be
              </p>
            </div>
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                Opening Greeting
              </label>
              <textarea
                value={settings.persona}
                onChange={(e) => update("persona", e.target.value)}
                rows={2}
                className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all resize-none"
              />
            </div>
          </div>
        </div>

        {/* ── Tone & Language ── */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="p-2.5 rounded-xl bg-purple-600/15 border border-purple-500/20 text-purple-300">
              <Globe size={16} />
            </div>
            <div>
              <h2 className="font-semibold text-white text-sm">Tone & Language</h2>
              <p className="text-xs text-zinc-600 mt-0.5">How AI communicates with customers</p>
            </div>
          </div>
          <div className="grid grid-cols-2 gap-6">
            {/* Tone */}
            <div>
              <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider block mb-3">
                Reply Tone
              </label>
              <div className="space-y-2.5">
                {[
                  { value: "friendly",     label: "Friendly",      desc: "Warm + emoji 😊" },
                  { value: "professional", label: "Professional",  desc: "Formal + polite" },
                  { value: "casual",       label: "Casual",        desc: "Relaxed + natural" },
                ].map((t) => (
                  <label key={t.value} className="flex items-start gap-3 cursor-pointer group">
                    <div
                      className={`mt-0.5 w-4 h-4 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all ${
                        settings.tone === t.value
                          ? "border-indigo-500 bg-indigo-500"
                          : "border-zinc-700 group-hover:border-zinc-500"
                      }`}
                      onClick={() => update("tone", t.value as Settings["tone"])}
                    >
                      {settings.tone === t.value && (
                        <div className="w-1.5 h-1.5 rounded-full bg-white" />
                      )}
                    </div>
                    <div>
                      <p className="text-sm text-zinc-300">{t.label}</p>
                      <p className="text-[11px] text-zinc-600">{t.desc}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>

            {/* Language */}
            <div>
              <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider block mb-3">
                Reply Language
              </label>
              <div className="space-y-2.5">
                {[
                  { value: "bangla",  label: "বাংলা",         desc: "Full Bangla replies" },
                  { value: "english", label: "English",       desc: "Full English replies" },
                  { value: "mixed",   label: "Mixed",         desc: "Banglish (both)" },
                ].map((l) => (
                  <label key={l.value} className="flex items-start gap-3 cursor-pointer group">
                    <div
                      className={`mt-0.5 w-4 h-4 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all ${
                        settings.language === l.value
                          ? "border-indigo-500 bg-indigo-500"
                          : "border-zinc-700 group-hover:border-zinc-500"
                      }`}
                      onClick={() => update("language", l.value as Settings["language"])}
                    >
                      {settings.language === l.value && (
                        <div className="w-1.5 h-1.5 rounded-full bg-white" />
                      )}
                    </div>
                    <div>
                      <p className="text-sm text-zinc-300">{l.label}</p>
                      <p className="text-[11px] text-zinc-600">{l.desc}</p>
                    </div>
                  </label>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* ── Safety & Limits ── */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="p-2.5 rounded-xl bg-sky-600/15 border border-sky-500/20 text-sky-300">
              <Shield size={16} />
            </div>
            <div>
              <h2 className="font-semibold text-white text-sm">Safety & Limits</h2>
              <p className="text-xs text-zinc-600 mt-0.5">Control AI behavior</p>
            </div>
          </div>
          <div className="space-y-5">
            {/* Confidence */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">
                  Confidence Threshold
                </label>
                <span className="text-xs text-indigo-400 font-mono font-semibold">
                  {settings.confidence}%
                </span>
              </div>
              <input
                type="range"
                min={50} max={100}
                value={settings.confidence}
                onChange={(e) => update("confidence", Number(e.target.value))}
                className="w-full accent-indigo-500"
              />
              <p className="text-[11px] text-zinc-700 mt-1.5">
                AI only replies when confidence ≥ {settings.confidence}%
              </p>
            </div>

            {/* Max replies */}
            <div>
              <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider block mb-2">
                Max AI Replies per Thread
              </label>
              <div className="flex items-center gap-2">
                {[3, 5, 10, 20, 50].map((n) => (
                  <button
                    key={n}
                    onClick={() => update("max_replies", n)}
                    className={`px-4 py-2 rounded-xl text-sm font-medium transition-all border ${
                      settings.max_replies === n
                        ? "bg-indigo-600 border-indigo-500 text-white"
                        : "bg-white/5 border-white/8 text-zinc-400 hover:text-zinc-200"
                    }`}
                  >
                    {n}
                  </button>
                ))}
              </div>
            </div>

            {/* Escalate */}
            <div className="flex items-center justify-between p-4 bg-white/4 rounded-xl border border-white/6">
              <div>
                <p className="text-sm font-medium text-zinc-300">Escalate to human</p>
                <p className="text-xs text-zinc-600 mt-0.5">
                  Hand off when AI can&apos;t resolve the issue
                </p>
              </div>
              <button
                onClick={() => update("escalate", !settings.escalate)}
                className={`w-10 h-[22px] rounded-full relative transition-all duration-200 ${
                  settings.escalate ? "bg-indigo-600" : "bg-zinc-700"
                }`}
              >
                <div className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all duration-200 ${
                  settings.escalate ? "left-5" : "left-0.5"
                }`} />
              </button>
            </div>
          </div>
        </div>

        {/* ── Live AI Test ── */}
        <div className="glass rounded-2xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="p-2.5 rounded-xl bg-amber-600/15 border border-amber-500/20 text-amber-300">
              <SendHorizonal size={16} />
            </div>
            <div>
              <h2 className="font-semibold text-white text-sm">Test AI Reply</h2>
              <p className="text-xs text-zinc-600 mt-0.5">
                Send a test message to see what AI would reply
              </p>
            </div>
          </div>

          <div className="flex items-center gap-3 mb-4">
            <input
              type="text"
              value={testMsg}
              onChange={(e) => setTestMsg(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && handleTest()}
              placeholder="e.g. দাম কত? / What is the price?"
              className="flex-1 bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/40 transition-all"
            />
            <button
              onClick={handleTest}
              disabled={testing || !testMsg.trim()}
              className="px-5 py-3 bg-amber-600 hover:bg-amber-500 disabled:opacity-40 text-white text-sm font-semibold rounded-xl transition-all flex items-center gap-2 whitespace-nowrap"
            >
              {testing
                ? <><Loader2 size={14} className="animate-spin" /> Testing…</>
                : <><SendHorizonal size={14} /> Test</>
              }
            </button>
          </div>

          {/* Test result */}
          {testResult && (
            <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20">
              <div className="flex items-center gap-2 mb-2">
                <CheckCircle2 size={14} className="text-emerald-400" />
                <span className="text-xs font-semibold text-emerald-400 uppercase tracking-wider">
                  AI Reply
                </span>
              </div>
              <p className="text-sm text-zinc-300 leading-relaxed">{testResult}</p>
            </div>
          )}

          {testError && (
            <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20">
              <div className="flex items-center gap-2 mb-1">
                <AlertCircle size={14} className="text-red-400" />
                <span className="text-xs font-semibold text-red-400 uppercase tracking-wider">Error</span>
              </div>
              <p className="text-sm text-red-400">{testError}</p>
              {testError.includes("GROQ_API_KEY") && (
                <div className="mt-3 p-3 bg-white/5 rounded-lg text-xs text-zinc-500 font-mono">
                  Add to .env.local:<br />
                  GROQ_API_KEY=your_key_here<br />
                  <span className="text-indigo-400">→ Get free key at console.groq.com</span>
                </div>
              )}
            </div>
          )}
        </div>

        {/* ── Save Actions ── */}
        <div className="flex items-center justify-between">
          <button
            onClick={() => { setSettings(DEFAULTS); setSaveStatus("idle"); }}
            className="flex items-center gap-2 px-4 py-2.5 text-sm text-zinc-500 hover:text-zinc-300 glass rounded-xl border border-white/8 transition-all"
          >
            <RotateCcw size={14} />
            Reset defaults
          </button>

          <button
            onClick={handleSave}
            disabled={saving}
            className={`flex items-center gap-2 px-6 py-2.5 text-sm font-semibold rounded-xl transition-all glow-sm ${
              saveStatus === "saved"
                ? "bg-emerald-600 text-white"
                : saveStatus === "error"
                ? "bg-red-600 text-white"
                : "bg-indigo-600 hover:bg-indigo-500 text-white"
            } disabled:opacity-50`}
          >
            {saving ? (
              <><Loader2 size={14} className="animate-spin" /> Saving…</>
            ) : saveStatus === "saved" ? (
              <><CheckCircle2 size={14} /> Saved!</>
            ) : saveStatus === "error" ? (
              <><AlertCircle size={14} /> Failed — retry</>
            ) : (
              <><Save size={14} /> Save Settings</>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

'@ | Set-Content -Path '.\app\dashboard\ai-settings\page.tsx' -Encoding UTF8
