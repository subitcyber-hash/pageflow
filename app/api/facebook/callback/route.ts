import { NextResponse } from "next/server";
import { getSupabaseServer } from "@/lib/server-auth";
import {
  exchangeCodeForToken,
  getUserPages,
  subscribePageToWebhook,
} from "@/lib/facebook/graph";

/**
 * GET /api/facebook/callback
 * Called by Facebook after user grants permissions.
 * Exchanges code â†’ token â†’ fetches pages â†’ saves to DB â†’ subscribes webhook.
 */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const code    = searchParams.get("code");
  const state   = searchParams.get("state");
  const fbError = searchParams.get("error");

  const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

  // User denied permission
  if (fbError) {
    console.error("[FB Callback] User denied:", fbError);
    return NextResponse.redirect(
      `${baseUrl}/dashboard/pages?fb_error=denied`
    );
  }

  if (!code || !state) {
    return NextResponse.redirect(
      `${baseUrl}/dashboard/pages?fb_error=missing_params`
    );
  }

  try {
    // Decode user ID from state
    const userId = Buffer.from(state, "base64").toString("utf-8");

    if (!userId) {
      return NextResponse.redirect(
        `${baseUrl}/dashboard/pages?fb_error=invalid_state`
      );
    }

    // 1. Exchange code for user access token
    const tokenResult = await exchangeCodeForToken(code);
    if (tokenResult.error) {
      console.error("[FB Callback] Token error:", tokenResult.error);
      return NextResponse.redirect(
        `${baseUrl}/dashboard/pages?fb_error=token_failed`
      );
    }

    // 2. Get user''s Facebook pages
    const pagesResult = await getUserPages(tokenResult.data.access_token);
    if (pagesResult.error) {
      console.error("[FB Callback] Pages error:", pagesResult.error);
      return NextResponse.redirect(
        `${baseUrl}/dashboard/pages?fb_error=pages_failed`
      );
    }

    const fbPages = pagesResult.data;
    if (fbPages.length === 0) {
      return NextResponse.redirect(
        `${baseUrl}/dashboard/pages?fb_error=no_pages`
      );
    }

    // 3. Save pages to DB
    const supabase = await getSupabaseServer();

    let savedCount = 0;
    for (const fbPage of fbPages) {
      // Upsert page â€” update if already exists (by facebook_page_id)
      const { error } = await supabase
        .from("pages")
        .upsert(
          {
            user_id:          userId,
            facebook_page_id: fbPage.id,
            name:             fbPage.name,
            category:         fbPage.category ?? "Business",
            followers:        fbPage.fan_count ?? 0,
            access_token:     fbPage.access_token,
            status:           "active",
          },
          { onConflict: "facebook_page_id" }
        );

      if (error) {
        console.error(`[FB Callback] Failed to save page ${fbPage.name}:`, error.message);
        continue;
      }

      // 4. Subscribe page to webhook
      if (process.env.FACEBOOK_APP_ID) {
        const subResult = await subscribePageToWebhook(
          fbPage.id,
          fbPage.access_token
        );
        if (subResult.error) {
          console.warn(`[FB Callback] Webhook sub failed for ${fbPage.name}:`, subResult.error);
        }
      }

      savedCount++;
    }

    return NextResponse.redirect(
      `${baseUrl}/dashboard/pages?fb_connected=${savedCount}`
    );
  } catch (err) {
    console.error("[FB Callback] Unexpected error:", err);
    return NextResponse.redirect(
      `${baseUrl}/dashboard/pages?fb_error=server_error`
    );
  }
}

