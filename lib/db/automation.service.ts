import type { SupabaseClient } from "@supabase/supabase-js";
import type { ServiceResult } from "./pages.service";

// â”€â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Service â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export const AutomationService = {
  // GET all automations for a page â€” verifies page ownership first
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

  // POST create automation â€” verifies page ownership before insert
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

  // PATCH update automation â€” verifies ownership via page join
  async update(
    supabase: SupabaseClient,
    userId: string,
    automationId: string,
    input: UpdateAutomationInput
  ): Promise<ServiceResult<Automation>> {
    // Verify ownership: automation â†’ page â†’ user
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

  // DELETE automation â€” verifies ownership
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

