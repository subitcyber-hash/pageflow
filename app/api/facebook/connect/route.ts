import { NextResponse } from "next/server";
import { requireAuth, ApiError } from "@/lib/server-auth";
import { getFacebookOAuthUrl } from "@/lib/facebook/graph";

/**
 * GET /api/facebook/connect
 * Initiates Facebook OAuth flow.
 * Redirects user to Facebook login/permissions page.
 */
export async function GET() {
  try {
    const { user } = await requireAuth().catch((r) => { throw r; });

    if (!process.env.FACEBOOK_APP_ID) {
      return ApiError.internal(
        "FACEBOOK_APP_ID not configured. Add it to .env.local"
      );
    }

    // State = user ID (used to identify user when FB redirects back)
    const state      = Buffer.from(user.id).toString("base64");
    const oauthUrl   = getFacebookOAuthUrl(state);

    return NextResponse.redirect(oauthUrl);
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[GET /api/facebook/connect]", err);
    return ApiError.internal();
  }
}

