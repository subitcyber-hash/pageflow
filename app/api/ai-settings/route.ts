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
          persona:       "",
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