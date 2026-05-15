import type { SupabaseClient } from "@supabase/supabase-js";

// â”€â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Select columns (avoid SELECT *) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const PAGE_COLUMNS = "id, user_id, name, status, category, followers, created_at";

// â”€â”€â”€ Service â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // GET single page â€” ownership enforced at query level
  async getById(
    supabase: SupabaseClient,
    userId: string,
    pageId: string
  ): Promise<ServiceResult<Page>> {
    const { data, error } = await supabase
      .from("pages")
      .select(PAGE_COLUMNS)
      .eq("id", pageId)
      .eq("user_id", userId) // â† multi-tenant guard
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
        user_id: userId, // â† always from server, never from client
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

  // PATCH update page â€” ownership enforced
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
      .eq("user_id", userId) // â† ownership check in the UPDATE itself
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

  // DELETE page â€” ownership enforced
  async delete(
    supabase: SupabaseClient,
    userId: string,
    pageId: string
  ): Promise<ServiceResult<{ id: string }>> {
    const { data, error } = await supabase
      .from("pages")
      .delete()
      .eq("id", pageId)
      .eq("user_id", userId) // â† ownership check
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

