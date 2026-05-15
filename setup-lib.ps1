# Run this in PowerShell inside your project folder
# PS D:\Downloads\pageflow-saas-starter> .\setup-lib.ps1

New-Item -ItemType Directory -Force -Path ".\lib" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib\ai" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib\db" | Out-Null

@'
import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import type { SupabaseClient, User } from "@supabase/supabase-js";

// ─── Supabase server instance ────────────────────────────────────────────────

export async function getSupabaseServer(): Promise<SupabaseClient> {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Read-only in Server Components — safe to ignore
          }
        },
      },
    }
  );
}

// ─── Auth guard ───────────────────────────────────────────────────────────────
// Returns authenticated user or throws a 401 NextResponse.
// Usage:
//   const { user, supabase } = await requireAuth();

export type AuthContext = {
  user: User;
  supabase: SupabaseClient;
};

export async function requireAuth(): Promise<AuthContext> {
  const supabase = await getSupabaseServer();

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    // Throw a Response so API routes can return it directly:
    //   const auth = await requireAuth().catch((r) => r);
    //   if (auth instanceof Response) return auth;
    throw NextResponse.json(
      { error: "Unauthorized", code: "AUTH_REQUIRED" },
      { status: 401 }
    );
  }

  return { user, supabase };
}

// ─── Standard error responses ────────────────────────────────────────────────

export const ApiError = {
  unauthorized: () =>
    NextResponse.json({ error: "Unauthorized", code: "AUTH_REQUIRED" }, { status: 401 }),

  forbidden: () =>
    NextResponse.json({ error: "Forbidden", code: "ACCESS_DENIED" }, { status: 403 }),

  notFound: (resource = "Resource") =>
    NextResponse.json({ error: `${resource} not found`, code: "NOT_FOUND" }, { status: 404 }),

  badRequest: (message: string) =>
    NextResponse.json({ error: message, code: "BAD_REQUEST" }, { status: 400 }),

  internal: (message = "Internal server error") =>
    NextResponse.json({ error: message, code: "INTERNAL_ERROR" }, { status: 500 }),
};

// ─── Input sanitization ───────────────────────────────────────────────────────

export function sanitizeString(value: unknown, maxLength = 255): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) return null;
  return trimmed;
}

'@ | Set-Content -Path '.\lib\server-auth.ts' -Encoding UTF8

@'
import type { SupabaseClient } from "@supabase/supabase-js";

// ─── Types ────────────────────────────────────────────────────────────────────

export type Page = {
  id: string;
  user_id: string;
  name: string;
  status: string;
  category: string | null;
  followers: number;
  created_at: string;
};

export type CreatePageInput = {
  name: string;
  category?: string;
};

export type UpdatePageInput = {
  name?: string;
  status?: string;
  category?: string;
};

export type ServiceResult<T> =
  | { data: T; error: null }
  | { data: null; error: { message: string; code: string } };

// ─── Select columns (avoid SELECT *) ─────────────────────────────────────────

const PAGE_COLUMNS = "id, user_id, name, status, category, followers, created_at";

// ─── Service ──────────────────────────────────────────────────────────────────

export const PagesService = {
  // GET all pages for authenticated user
  async getAll(supabase: SupabaseClient, userId: string): Promise<ServiceResult<Page[]>> {
    const { data, error } = await supabase
      .from("pages")
      .select(PAGE_COLUMNS)
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("[PagesService.getAll]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data: data ?? [], error: null };
  },

  // GET single page — ownership enforced at query level
  async getById(
    supabase: SupabaseClient,
    userId: string,
    pageId: string
  ): Promise<ServiceResult<Page>> {
    const { data, error } = await supabase
      .from("pages")
      .select(PAGE_COLUMNS)
      .eq("id", pageId)
      .eq("user_id", userId) // ← multi-tenant guard
      .single();

    if (error) {
      if (error.code === "PGRST116") {
        return { data: null, error: { message: "Page not found", code: "NOT_FOUND" } };
      }
      console.error("[PagesService.getById]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // POST create new page
  async create(
    supabase: SupabaseClient,
    userId: string,
    input: CreatePageInput
  ): Promise<ServiceResult<Page>> {
    const { data, error } = await supabase
      .from("pages")
      .insert({
        user_id: userId, // ← always from server, never from client
        name: input.name,
        category: input.category ?? "Business",
        status: "active",
        followers: 0,
      })
      .select(PAGE_COLUMNS)
      .single();

    if (error) {
      console.error("[PagesService.create]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // PATCH update page — ownership enforced
  async update(
    supabase: SupabaseClient,
    userId: string,
    pageId: string,
    input: UpdatePageInput
  ): Promise<ServiceResult<Page>> {
    // Verify ownership first (single query approach)
    const { data, error } = await supabase
      .from("pages")
      .update({
        ...(input.name     !== undefined && { name:     input.name     }),
        ...(input.status   !== undefined && { status:   input.status   }),
        ...(input.category !== undefined && { category: input.category }),
      })
      .eq("id", pageId)
      .eq("user_id", userId) // ← ownership check in the UPDATE itself
      .select(PAGE_COLUMNS)
      .single();

    if (error) {
      if (error.code === "PGRST116") {
        return { data: null, error: { message: "Page not found", code: "NOT_FOUND" } };
      }
      console.error("[PagesService.update]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // DELETE page — ownership enforced
  async delete(
    supabase: SupabaseClient,
    userId: string,
    pageId: string
  ): Promise<ServiceResult<{ id: string }>> {
    const { data, error } = await supabase
      .from("pages")
      .delete()
      .eq("id", pageId)
      .eq("user_id", userId) // ← ownership check
      .select("id")
      .single();

    if (error) {
      if (error.code === "PGRST116") {
        return { data: null, error: { message: "Page not found", code: "NOT_FOUND" } };
      }
      console.error("[PagesService.delete]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data: { id: data.id }, error: null };
  },
};

'@ | Set-Content -Path '.\lib\db\pages.service.ts' -Encoding UTF8

@'
import type { SupabaseClient } from "@supabase/supabase-js";
import type { ServiceResult } from "./pages.service";

// ─── Types ────────────────────────────────────────────────────────────────────

export type Automation = {
  id: string;
  page_id: string;
  trigger: string;
  reply: string;
  enabled: boolean;
  created_at: string;
};

export type CreateAutomationInput = {
  page_id: string;
  trigger: string;
  reply: string;
};

export type UpdateAutomationInput = {
  trigger?: string;
  reply?: string;
  enabled?: boolean;
};

const AUTOMATION_COLUMNS = "id, page_id, trigger, reply, enabled, created_at";

// ─── Service ──────────────────────────────────────────────────────────────────

export const AutomationService = {
  // GET all automations for a page — verifies page ownership first
  async getByPage(
    supabase: SupabaseClient,
    userId: string,
    pageId: string
  ): Promise<ServiceResult<Automation[]>> {
    // Join through pages to enforce user ownership
    const { data, error } = await supabase
      .from("automations")
      .select(`${AUTOMATION_COLUMNS}, pages!inner(user_id)`)
      .eq("page_id", pageId)
      .eq("pages.user_id", userId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("[AutomationService.getByPage]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    // Strip joined pages column from response
    const clean = (data ?? []).map(({ pages: _pages, ...rest }) => rest as Automation);
    return { data: clean, error: null };
  },

  // POST create automation — verifies page ownership before insert
  async create(
    supabase: SupabaseClient,
    userId: string,
    input: CreateAutomationInput
  ): Promise<ServiceResult<Automation>> {
    // Verify the page belongs to this user
    const { data: page, error: pageError } = await supabase
      .from("pages")
      .select("id")
      .eq("id", input.page_id)
      .eq("user_id", userId)
      .single();

    if (pageError || !page) {
      return {
        data: null,
        error: { message: "Page not found or access denied", code: "NOT_FOUND" },
      };
    }

    const { data, error } = await supabase
      .from("automations")
      .insert({
        page_id: input.page_id,
        trigger: input.trigger,
        reply:   input.reply,
        enabled: true,
      })
      .select(AUTOMATION_COLUMNS)
      .single();

    if (error) {
      console.error("[AutomationService.create]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // PATCH update automation — verifies ownership via page join
  async update(
    supabase: SupabaseClient,
    userId: string,
    automationId: string,
    input: UpdateAutomationInput
  ): Promise<ServiceResult<Automation>> {
    // Verify ownership: automation → page → user
    const { data: existing, error: fetchError } = await supabase
      .from("automations")
      .select(`id, pages!inner(user_id)`)
      .eq("id", automationId)
      .eq("pages.user_id", userId)
      .single();

    if (fetchError || !existing) {
      return {
        data: null,
        error: { message: "Automation not found or access denied", code: "NOT_FOUND" },
      };
    }

    const { data, error } = await supabase
      .from("automations")
      .update({
        ...(input.trigger !== undefined && { trigger: input.trigger }),
        ...(input.reply   !== undefined && { reply:   input.reply   }),
        ...(input.enabled !== undefined && { enabled: input.enabled }),
      })
      .eq("id", automationId)
      .select(AUTOMATION_COLUMNS)
      .single();

    if (error) {
      console.error("[AutomationService.update]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // DELETE automation — verifies ownership
  async delete(
    supabase: SupabaseClient,
    userId: string,
    automationId: string
  ): Promise<ServiceResult<{ id: string }>> {
    const { data: existing, error: fetchError } = await supabase
      .from("automations")
      .select(`id, pages!inner(user_id)`)
      .eq("id", automationId)
      .eq("pages.user_id", userId)
      .single();

    if (fetchError || !existing) {
      return {
        data: null,
        error: { message: "Automation not found or access denied", code: "NOT_FOUND" },
      };
    }

    const { error } = await supabase
      .from("automations")
      .delete()
      .eq("id", automationId);

    if (error) {
      console.error("[AutomationService.delete]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data: { id: automationId }, error: null };
  },
};

'@ | Set-Content -Path '.\lib\db\automation.service.ts' -Encoding UTF8

@'
/**
 * lib/ai/groq.ts
 * Groq AI integration for smart reply generation.
 * Install: npm install groq-sdk
 * Add to .env.local: GROQ_API_KEY=your_key_here
 */

// import Groq from "groq-sdk";

// ─── Types ────────────────────────────────────────────────────────────────────

export type GenerateReplyInput = {
  userMessage: string;
  pageContext?: string;    // e.g. "We are a bakery selling cakes"
  language?: string;       // e.g. "English", "Filipino"
  tone?: "friendly" | "professional" | "casual";
  maxTokens?: number;
};

export type GenerateReplyResult =
  | { reply: string; error: null }
  | { reply: null; error: string };

// ─── Client (singleton) ───────────────────────────────────────────────────────

// let groqClient: Groq | null = null;
//
// function getGroqClient(): Groq {
//   if (!groqClient) {
//     if (!process.env.GROQ_API_KEY) {
//       throw new Error("GROQ_API_KEY is not set");
//     }
//     groqClient = new Groq({ apiKey: process.env.GROQ_API_KEY });
//   }
//   return groqClient;
// }

// ─── Service ──────────────────────────────────────────────────────────────────

export async function generateReply(input: GenerateReplyInput): Promise<GenerateReplyResult> {
  // TODO: uncomment when groq-sdk is installed
  //
  // const groq = getGroqClient();
  //
  // const systemPrompt = [
  //   `You are a helpful customer service assistant.`,
  //   input.pageContext ? `Context: ${input.pageContext}` : "",
  //   `Tone: ${input.tone ?? "friendly"}`,
  //   `Reply in: ${input.language ?? "English"}`,
  //   `Keep replies concise and helpful. Do not use markdown.`,
  // ].filter(Boolean).join("\n");
  //
  // try {
  //   const completion = await groq.chat.completions.create({
  //     model: "llama3-8b-8192",
  //     messages: [
  //       { role: "system",    content: systemPrompt      },
  //       { role: "user",      content: input.userMessage },
  //     ],
  //     max_tokens: input.maxTokens ?? 300,
  //     temperature: 0.7,
  //   });
  //
  //   const reply = completion.choices[0]?.message?.content?.trim();
  //   if (!reply) throw new Error("Empty response from Groq");
  //
  //   return { reply, error: null };
  // } catch (err) {
  //   console.error("[Groq] generateReply error:", err);
  //   return { reply: null, error: err instanceof Error ? err.message : "AI error" };
  // }

  // Placeholder until groq-sdk is installed
  console.warn("[Groq] generateReply called but Groq SDK not installed yet");
  return {
    reply: `Thanks for your message! We''ll get back to you shortly.`,
    error: null,
  };
}

'@ | Set-Content -Path '.\lib\ai\groq.ts' -Encoding UTF8
