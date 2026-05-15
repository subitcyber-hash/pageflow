import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { AutomationService } from "@/lib/db/automation.service";

type RouteContext = { params: Promise<{ id: string }> };

/**
 * PATCH /api/automation/[id]
 * Update trigger, reply, or enabled state.
 */
export async function PATCH(request: Request, { params }: RouteContext) {
  try {
    const { id } = await params;
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const updateInput: { trigger?: string; reply?: string; enabled?: boolean } = {};

    if (body.trigger !== undefined) {
      const trigger = sanitizeString(body.trigger, 500);
      if (!trigger) return ApiError.badRequest("'trigger' must be a non-empty string under 500 characters");
      updateInput.trigger = trigger;
    }

    if (body.reply !== undefined) {
      const reply = sanitizeString(body.reply, 2000);
      if (!reply) return ApiError.badRequest("'reply' must be a non-empty string under 2000 characters");
      updateInput.reply = reply;
    }

    if (body.enabled !== undefined) {
      if (typeof body.enabled !== "boolean") return ApiError.badRequest("'enabled' must be a boolean");
      updateInput.enabled = body.enabled;
    }

    if (Object.keys(updateInput).length === 0) {
      return ApiError.badRequest("No valid fields provided to update");
    }

    const { data, error } = await AutomationService.update(supabase, user.id, id, updateInput);

    if (error) {
      return error.code === "NOT_FOUND"
        ? ApiError.notFound("Automation")
        : ApiError.internal(error.message);
    }

    return NextResponse.json({ automation: data });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[PATCH /api/automation/[id]]", err);
    return ApiError.internal();
  }
}

/**
 * DELETE /api/automation/[id]
 */
export async function DELETE(_req: Request, { params }: RouteContext) {
  try {
    const { id } = await params;
    const { user, supabase } = await requireAuth().catch((r) => { throw r; });

    const { data, error } = await AutomationService.delete(supabase, user.id, id);

    if (error) {
      return error.code === "NOT_FOUND"
        ? ApiError.notFound("Automation")
        : ApiError.internal(error.message);
    }

    return NextResponse.json({ deleted: true, id: data.id });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[DELETE /api/automation/[id]]", err);
    return ApiError.internal();
  }
}
