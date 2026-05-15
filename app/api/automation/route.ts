import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { AutomationService } from "@/lib/db/automation.service";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS, canAddAutomation } from "@/lib/plans";

export async function GET(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    const { searchParams } = new URL(request.url);
    const pageId = searchParams.get("page_id");

    if (!pageId) return ApiError.badRequest("''page_id'' query parameter is required");

    const { data, error } = await AutomationService.getByPage(supabase, user.id, pageId);

    if (error) {
      return error.code === "NOT_FOUND"
        ? ApiError.notFound("Automations")
        : ApiError.internal(error.message);
    }

    return NextResponse.json({ automations: data, total: data.length });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/automation]", err);
    return ApiError.internal();
  }
}

export async function POST(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const pageId = sanitizeString(body.page_id);
    if (!pageId) return ApiError.badRequest("''page_id'' is required");

    // â”€â”€ Plan limit check â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    const plan = await SubscriptionService.getUserPlan(supabase, user.id);
    const { data: existing } = await AutomationService.getByPage(supabase, user.id, pageId);
    const currentCount = existing?.length ?? 0;

    if (!canAddAutomation(plan, currentCount)) {
      const limit = PLANS[plan].automations;
      return NextResponse.json(
        {
          error:      `Your ${PLANS[plan].name} plan allows ${limit} automation rule${limit === 1 ? "" : "s"} per page. Upgrade to add more.`,
          code:       "PLAN_LIMIT_REACHED",
          limit,
          current:    currentCount,
          plan,
          upgradeUrl: "/dashboard/billing",
        },
        { status: 403 }
      );
    }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    const trigger = sanitizeString(body.trigger, 500);
    if (!trigger) return ApiError.badRequest("''trigger'' is required and must be under 500 characters");

    const reply = sanitizeString(body.reply, 2000);
    if (!reply) return ApiError.badRequest("''reply'' is required and must be under 2000 characters");

    const { data, error } = await AutomationService.create(supabase, user.id, {
      page_id: pageId,
      trigger,
      reply,
    });

    if (error) {
      return error.code === "NOT_FOUND"
        ? ApiError.notFound("Page")
        : ApiError.internal(error.message);
    }

    return NextResponse.json({ automation: data }, { status: 201 });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/automation]", err);
    return ApiError.internal();
  }
}

