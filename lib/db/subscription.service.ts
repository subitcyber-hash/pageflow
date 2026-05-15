import type { SupabaseClient } from "@supabase/supabase-js";
import type { PlanId } from "@/lib/plans";
import type { ServiceResult } from "./pages.service";

// â”€â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export type Subscription = {
  id:                string;
  user_id:           string;
  plan:              PlanId;
  status:            "active" | "cancelled" | "expired" | "trialing";
  payment_method:    string | null;
  transaction_id:    string | null;
  amount:            number;
  currency:          string;
  current_period_start: string;
  current_period_end:   string;
  cancel_at_period_end: boolean;
  created_at:        string;
  updated_at:        string;
};

export type UsageStats = {
  pages:       number;
  automations: number;
  leads:       number;
  ai_replies:  number;
};

const SUB_COLUMNS = "id, user_id, plan, status, payment_method, transaction_id, amount, currency, current_period_start, current_period_end, cancel_at_period_end, created_at, updated_at";

// â”€â”€â”€ Service â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export const SubscriptionService = {
  // GET active subscription for user
  async get(
    supabase: SupabaseClient,
    userId: string
  ): Promise<ServiceResult<Subscription | null>> {
    const { data, error } = await supabase
      .from("subscriptions")
      .select(SUB_COLUMNS)
      .eq("user_id", userId)
      .in("status", ["active", "trialing"])
      .order("created_at", { ascending: false })
      .maybeSingle();

    if (error) {
      console.error("[SubscriptionService.get]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // GET all subscription history
  async getHistory(
    supabase: SupabaseClient,
    userId: string
  ): Promise<ServiceResult<Subscription[]>> {
    const { data, error } = await supabase
      .from("subscriptions")
      .select(SUB_COLUMNS)
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("[SubscriptionService.getHistory]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data: data ?? [], error: null };
  },

  // CREATE subscription after successful payment
  async create(
    supabase: SupabaseClient,
    userId: string,
    input: {
      plan:           PlanId;
      transaction_id: string;
      amount:         number;
      payment_method: string;
    }
  ): Promise<ServiceResult<Subscription>> {
    const now   = new Date();
    const end   = new Date(now);
    end.setMonth(end.getMonth() + 1);

    // Cancel any existing active subscriptions first
    await supabase
      .from("subscriptions")
      .update({ status: "cancelled", updated_at: now.toISOString() })
      .eq("user_id", userId)
      .in("status", ["active", "trialing"]);

    const { data, error } = await supabase
      .from("subscriptions")
      .insert({
        user_id:               userId,
        plan:                  input.plan,
        status:                "active",
        payment_method:        input.payment_method,
        transaction_id:        input.transaction_id,
        amount:                input.amount,
        currency:              "BDT",
        current_period_start:  now.toISOString(),
        current_period_end:    end.toISOString(),
        cancel_at_period_end:  false,
        updated_at:            now.toISOString(),
      })
      .select(SUB_COLUMNS)
      .single();

    if (error) {
      console.error("[SubscriptionService.create]", error.message);
      return { data: null, error: { message: error.message, code: "DB_ERROR" } };
    }

    return { data, error: null };
  },

  // GET current usage stats for a user
  async getUsage(
    supabase: SupabaseClient,
    userId: string
  ): Promise<ServiceResult<UsageStats>> {
    const [pagesRes, leadsRes] = await Promise.all([
      supabase
        .from("pages")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId),
      supabase
        .from("leads")
        .select("id", { count: "exact", head: true })
        .in(
          "page_id",
          (
            await supabase
              .from("pages")
              .select("id")
              .eq("user_id", userId)
          ).data?.map((p: { id: string }) => p.id) ?? []
        ),
    ]);

    return {
      data: {
        pages:       pagesRes.count      ?? 0,
        automations: 0,                        // computed per page when needed
        leads:       leadsRes.count      ?? 0,
        ai_replies:  0,                        // tracked separately in future
      },
      error: null,
    };
  },

  // GET plan for user (defaults to "free" if no active subscription)
  async getUserPlan(
    supabase: SupabaseClient,
    userId: string
  ): Promise<PlanId> {
    const { data } = await SubscriptionService.get(supabase, userId);
    return data?.plan ?? "free";
  },
};

