import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { generateReply, getFallbackReply } from "@/lib/ai/groq";
import { AISettingsService } from "@/lib/db/ai-settings.service";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS, canUseAI } from "@/lib/plans";

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
    if (!message) return ApiError.badRequest("''message'' is required");

    // â”€â”€ Plan limit check â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    const plan = await SubscriptionService.getUserPlan(supabase, user.id);

    if (!canUseAI(plan)) {
      return NextResponse.json(
        {
          error:      `AI replies are not available on the ${PLANS[plan].name} plan. Upgrade to Pro or Business.`,
          code:       "PLAN_LIMIT_REACHED",
          plan,
          upgradeUrl: "/dashboard/billing",
        },
        { status: 403 }
      );
    }
    // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    const pageId = body.page_id as string | undefined;

    const { data: settings } = await AISettingsService.get(
      supabase,
      user.id,
      pageId ?? null
    );

    if (settings && !settings.enabled) {
      return NextResponse.json({
        reply:   getFallbackReply(settings.language),
        source:  "fallback",
        reason:  "AI disabled",
      });
    }

    if (!process.env.GROQ_API_KEY) {
      return NextResponse.json(
        {
          error: "GROQ_API_KEY not configured",
          code:  "NO_API_KEY",
          hint:  "Add GROQ_API_KEY to your .env.local file. Get free key at console.groq.com",
        },
        { status: 503 }
      );
    }

    const result = await generateReply({
      userMessage:  message,
      businessName: settings?.business_name || undefined,
      businessInfo: settings?.business_info || undefined,
      persona:      settings?.persona       || undefined,
      language:     settings?.language      ?? "bangla",
      tone:         settings?.tone          ?? "friendly",
      maxTokens:    300,
    });

    if (result.error) {
      return NextResponse.json({ error: result.error, code: "AI_ERROR" }, { status: 500 });
    }

    return NextResponse.json({
      reply:      result.reply,
      source:     "groq",
      tokensUsed: result.tokensUsed,
      plan,
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

