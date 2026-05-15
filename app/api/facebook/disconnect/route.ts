import { NextResponse } from "next/server";
import { requireAuth, ApiError } from "@/lib/server-auth";

/**
 * POST /api/facebook/disconnect
 * Disconnects a Facebook page â€” removes access token, sets status to disconnected.
 * Body: { page_id: string }  (our DB page id, not Facebook page id)
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

    const pageId = body.page_id as string;
    if (!pageId) return ApiError.badRequest("page_id is required");

    // Ownership check + update in one query
    const { data, error } = await supabase
      .from("pages")
      .update({
        status:       "disconnected",
        access_token: null,
      })
      .eq("id", pageId)
      .eq("user_id", user.id)
      .select("id, name")
      .single();

    if (error || !data) {
      return ApiError.notFound("Page");
    }

    return NextResponse.json({
      success: true,
      message: `${data.name} has been disconnected.`,
    });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/facebook/disconnect]", err);
    return ApiError.internal();
  }
}

