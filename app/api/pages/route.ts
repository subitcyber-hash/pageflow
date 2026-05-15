import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { PagesService } from "@/lib/db/pages.service";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS, canAddPage } from "@/lib/plans";

export async function GET() {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });
    const { data, error } = await PagesService.getAll(supabase, user.id);

    if (error) {
      return error.code === "NOT_FOUND"
        ? ApiError.notFound("Pages")
        : ApiError.internal(error.message);
    }

    return NextResponse.json({ pages: data, total: data.length });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/pages]", err);
    return ApiError.internal();
  }
}

export async function POST(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    // â”€â”€ Plan limit check â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    const plan = await SubscriptionService.getUserPlan(supabase, user.id);
    const { data: existing } = await PagesService.getAll(supabase, user.id);
    const currentCount = existing?.length ?? 0;

    if (!canAddPage(plan, currentCount)) {
      const limit = PLANS[plan].pages;
      return NextResponse.json(
        {
          error:    `Your ${PLANS[plan].name} plan allows a maximum of ${limit} page${limit === 1 ? "" : "s"}. Upgrade to add more.`,
          code:     "PLAN_LIMIT_REACHED",
          limit,
          current:  currentCount,
          plan,
          upgradeUrl: "/dashboard/billing",
        },
        { status: 403 }
      );
    }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const name = sanitizeString(body.name);
    if (!name) {
      return ApiError.badRequest("''name'' is required and must be a non-empty string under 255 characters");
    }

    const category = sanitizeString(body.category ?? "Business") ?? "Business";

    const { data, error } = await PagesService.create(supabase, user.id, { name, category });

    if (error) return ApiError.internal(error.message);

    return NextResponse.json({ page: data }, { status: 201 });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/pages]", err);
    return ApiError.internal();
  }
}

