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
  // GET settings for user
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

  // UPSERT — manual select → insert or update
  // Standard Supabase upsert onConflict fails with nullable columns.
  async upsert(
    supabase: SupabaseClient,
    userId: string,
    input: UpsertAISettingsInput
  ): Promise<ServiceResult<AISettings>> {
    const pageId = input.page_id ?? null;

    // 1. Check if a row already exists
    let existQuery = supabase
      .from("ai_settings")
      .select("id")
      .eq("user_id", userId);

    if (pageId) {
      existQuery = existQuery.eq("page_id", pageId);
    } else {
      existQuery = existQuery.is("page_id", null);
    }

    const { data: existing, error: findError } = await existQuery.maybeSingle();

    if (findError) {
      console.error("[AISettingsService.upsert find]", findError.message);
      return { data: null, error: { message: findError.message, code: "DB_ERROR" } };
    }

    const payload = {
      user_id:       userId,
      page_id:       pageId,
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
    };

    let result;

    if (existing?.id) {
      // 2a. UPDATE existing row
      result = await supabase
        .from("ai_settings")
        .update(payload)
        .eq("id", existing.id)
        .select(COLUMNS)
        .single();
    } else {
      // 2b. INSERT new row
      result = await supabase
        .from("ai_settings")
        .insert(payload)
        .select(COLUMNS)
        .single();
    }

    if (result.error) {
      console.error("[AISettingsService.upsert save]", result.error.message);
      return { data: null, error: { message: result.error.message, code: "DB_ERROR" } };
    }

    return { data: result.data, error: null };
  },
};