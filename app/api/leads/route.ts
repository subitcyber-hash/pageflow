import { NextResponse } from "next/server";
import { requireAuth, ApiError } from "@/lib/server-auth";

/**
 * GET /api/leads?page_id=<uuid>  (optional filter)
 * Returns all leads across user's pages, or filtered by page.
 */
export async function GET(request: Request) {
  try {
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    const { searchParams } = new URL(request.url);
    const pageId = searchParams.get("page_id");

    // Get all page IDs for this user first
    const { data: userPages, error: pagesError } = await supabase
      .from("pages")
      .select("id, name")
      .eq("user_id", user.id);

    if (pagesError) {
      return ApiError.internal(pagesError.message);
    }

    const pageIds = (userPages ?? []).map((p: { id: string }) => p.id);

    if (pageIds.length === 0) {
      return NextResponse.json({ leads: [], total: 0 });
    }

    // Build query — scoped to user's pages only
    let query = supabase
      .from("leads")
      .select("id, page_id, name, message, created_at")
      .in("page_id", pageIds)
      .order("created_at", { ascending: false })
      .limit(100);

    if (pageId && pageIds.includes(pageId)) {
      query = query.eq("page_id", pageId);
    }

    const { data, error } = await query;

    if (error) {
      return ApiError.internal(error.message);
    }

    // Attach page name to each lead
    const pageMap = Object.fromEntries(
      (userPages ?? []).map((p: { id: string; name: string }) => [p.id, p.name])
    );

    const leads = (data ?? []).map((lead: {
      id: string;
      page_id: string;
      name: string | null;
      message: string | null;
      created_at: string;
    }) => ({
      ...lead,
      page_name: pageMap[lead.page_id] ?? "Unknown Page",
    }));

    return NextResponse.json({ leads, total: leads.length });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/leads]", err);
    return ApiError.internal();
  }
}

/**
 * POST /api/leads
 * Called internally by the webhook handler when a new message arrives.
 * Body: { page_id, name, message }
 */
export async function POST(request: Request) {
  try {
    const { supabase } = await requireAuth().catch((r) => { throw r; });

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const { data, error } = await supabase
      .from("leads")
      .insert({
        page_id: body.page_id,
        name:    body.name    ?? "Unknown",
        message: body.message ?? "",
      })
      .select()
      .single();

    if (error) return ApiError.internal(error.message);

    return NextResponse.json({ lead: data }, { status: 201 });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/leads]", err);
    return ApiError.internal();
  }
}
