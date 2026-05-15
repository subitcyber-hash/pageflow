import { NextResponse } from "next/server";
import { requireAuth, ApiError } from "@/lib/server-auth";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS } from "@/lib/plans";

/**
 * GET /api/subscription
 * Returns current subscription, plan details, and usage stats.
 */
export async function GET() {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    const [subResult, usageResult, historyResult] = await Promise.all([
      SubscriptionService.get(supabase, user.id),
      SubscriptionService.getUsage(supabase, user.id),
      SubscriptionService.getHistory(supabase, user.id),
    ]);

    const plan   = subResult.data?.plan ?? "free";
    const planDetails = PLANS[plan];

    return NextResponse.json({
      subscription: subResult.data,
      plan:         planDetails,
      usage:        usageResult.data,
      history:      historyResult.data ?? [],
      isFreePlan:   plan === "free",
    });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/subscription]", err);
    return ApiError.internal();
  }
}

