# Phase 5 setup script - run from project root
$OutputEncoding = [System.Text.Encoding]::UTF8

New-Item -ItemType Directory -Force -Path ".\app" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\facebook" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\facebook\callback" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\facebook\connect" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\facebook\disconnect" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\webhook" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\api\webhook\facebook" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard" | Out-Null
New-Item -ItemType Directory -Force -Path ".\app\dashboard\pages" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib" | Out-Null
New-Item -ItemType Directory -Force -Path ".\lib\facebook" | Out-Null

@'
/**
 * lib/facebook/graph.ts
 * Facebook Graph API client.
 * All Facebook API calls go through this file.
 */

const GRAPH_VERSION = "v19.0";
const GRAPH_BASE    = `https://graph.facebook.com/${GRAPH_VERSION}`;

// ─── Types ────────────────────────────────────────────────────────────────────

export type FacebookPage = {
  id:           string;
  name:         string;
  access_token: string;
  category:     string;
  fan_count?:   number;
  picture?:     { data: { url: string } };
};

export type FacebookUser = {
  id:    string;
  name:  string;
  email: string;
};

export type GraphResult<T> =
  | { data: T;    error: null }
  | { data: null; error: string };

// ─── OAuth helpers ────────────────────────────────────────────────────────────

export function getFacebookOAuthUrl(state: string): string {
  const appId      = process.env.FACEBOOK_APP_ID!;
  const baseUrl    = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
  const redirectUri = `${baseUrl}/api/facebook/callback`;

  const params = new URLSearchParams({
    client_id:     appId,
    redirect_uri:  redirectUri,
    state,
    scope: [
      "pages_show_list",
      "pages_messaging",
      "pages_read_engagement",
      "pages_manage_metadata",
    ].join(","),
  });

  return `https://www.facebook.com/dialog/oauth?${params.toString()}`;
}

// ─── Exchange code for user access token ──────────────────────────────────────

export async function exchangeCodeForToken(
  code: string
): Promise<GraphResult<{ access_token: string; token_type: string }>> {
  const appId      = process.env.FACEBOOK_APP_ID!;
  const appSecret  = process.env.FACEBOOK_APP_SECRET!;
  const baseUrl    = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";
  const redirectUri = `${baseUrl}/api/facebook/callback`;

  const params = new URLSearchParams({
    client_id:     appId,
    client_secret: appSecret,
    redirect_uri:  redirectUri,
    code,
  });

  try {
    const res  = await fetch(`${GRAPH_BASE}/oauth/access_token?${params}`);
    const data = await res.json() as { access_token?: string; token_type?: string; error?: { message: string } };

    if (data.error) return { data: null, error: data.error.message };
    if (!data.access_token) return { data: null, error: "No access token received" };

    return { data: { access_token: data.access_token, token_type: data.token_type ?? "bearer" }, error: null };
  } catch (err) {
    return { data: null, error: err instanceof Error ? err.message : "Token exchange failed" };
  }
}

// ─── Get user''s pages ─────────────────────────────────────────────────────────

export async function getUserPages(
  userAccessToken: string
): Promise<GraphResult<FacebookPage[]>> {
  try {
    const res  = await fetch(
      `${GRAPH_BASE}/me/accounts?fields=id,name,access_token,category,fan_count,picture&access_token=${userAccessToken}`
    );
    const data = await res.json() as { data?: FacebookPage[]; error?: { message: string } };

    if (data.error) return { data: null, error: data.error.message };

    return { data: data.data ?? [], error: null };
  } catch (err) {
    return { data: null, error: err instanceof Error ? err.message : "Failed to fetch pages" };
  }
}

// ─── Subscribe page to webhook ────────────────────────────────────────────────

export async function subscribePageToWebhook(
  pageId: string,
  pageAccessToken: string
): Promise<GraphResult<boolean>> {
  try {
    const res  = await fetch(`${GRAPH_BASE}/${pageId}/subscribed_apps`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        subscribed_fields: ["messages", "messaging_postbacks", "feed"],
        access_token:      pageAccessToken,
      }),
    });
    const data = await res.json() as { success?: boolean; error?: { message: string } };

    if (data.error) return { data: null, error: data.error.message };

    return { data: true, error: null };
  } catch (err) {
    return { data: null, error: err instanceof Error ? err.message : "Webhook subscription failed" };
  }
}

// ─── Send message via Messenger ───────────────────────────────────────────────

export async function sendMessage(
  pageAccessToken: string,
  recipientId:     string,
  message:         string
): Promise<GraphResult<{ message_id: string }>> {
  try {
    const res  = await fetch(`${GRAPH_BASE}/me/messages`, {
      method:  "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization:  `Bearer ${pageAccessToken}`,
      },
      body: JSON.stringify({
        recipient: { id: recipientId },
        message:   { text: message },
        messaging_type: "RESPONSE",
      }),
    });
    const data = await res.json() as { message_id?: string; error?: { message: string } };

    if (data.error) return { data: null, error: data.error.message };
    if (!data.message_id) return { data: null, error: "No message_id returned" };

    return { data: { message_id: data.message_id }, error: null };
  } catch (err) {
    return { data: null, error: err instanceof Error ? err.message : "Failed to send message" };
  }
}

// ─── Verify webhook signature ─────────────────────────────────────────────────

export async function verifyWebhookSignature(
  body:      string,
  signature: string | null
): Promise<boolean> {
  if (!signature) return false;

  const appSecret = process.env.FACEBOOK_APP_SECRET!;
  if (!appSecret) return false;

  try {
    const encoder   = new TextEncoder();
    const keyData   = encoder.encode(appSecret);
    const msgData   = encoder.encode(body);
    const cryptoKey = await crypto.subtle.importKey(
      "raw", keyData,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const sigBuffer = await crypto.subtle.sign("HMAC", cryptoKey, msgData);
    const sigHex    = Array.from(new Uint8Array(sigBuffer))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    const expected = `sha256=${sigHex}`;
    return signature === expected;
  } catch {
    return false;
  }
}

// ─── Get user profile from PSID ──────────────────────────────────────────────

export async function getUserProfile(
  psid:            string,
  pageAccessToken: string
): Promise<GraphResult<{ name: string; id: string }>> {
  try {
    const res  = await fetch(
      `${GRAPH_BASE}/${psid}?fields=name,id&access_token=${pageAccessToken}`
    );
    const data = await res.json() as { name?: string; id?: string; error?: { message: string } };

    if (data.error) return { data: null, error: data.error.message };

    return {
      data: { name: data.name ?? "Unknown", id: data.id ?? psid },
      error: null,
    };
  } catch (err) {
    return { data: null, error: err instanceof Error ? err.message : "Failed to get profile" };
  }
}

'@ | Set-Content -Path '.\lib\facebook\graph.ts' -Encoding UTF8

@'
/**
 * lib/facebook/matcher.ts
 * Matches incoming messages to automation rules.
 * Supports keyword matching with future regex/AI fallback.
 */

import type { SupabaseClient } from "@supabase/supabase-js";

export type MatchedRule = {
  id:      string;
  trigger: string;
  reply:   string;
};

// ─── Find matching automation rule ───────────────────────────────────────────

export async function findMatchingRule(
  supabase:  SupabaseClient,
  pageDbId:  string,
  message:   string
): Promise<MatchedRule | null> {
  // Load all enabled rules for this page
  const { data: rules, error } = await supabase
    .from("automations")
    .select("id, trigger, reply")
    .eq("page_id", pageDbId)
    .eq("enabled", true);

  if (error || !rules || rules.length === 0) return null;

  const msgLower = message.toLowerCase().trim();

  // Priority 1: exact match
  const exactMatch = rules.find(
    (r: MatchedRule) => r.trigger.toLowerCase().trim() === msgLower
  );
  if (exactMatch) return exactMatch;

  // Priority 2: message contains trigger keyword
  const containsMatch = rules.find(
    (r: MatchedRule) => msgLower.includes(r.trigger.toLowerCase().trim())
  );
  if (containsMatch) return containsMatch;

  // Priority 3: any trigger word appears in message
  const wordMatch = rules.find((r: MatchedRule) => {
    const words = r.trigger.toLowerCase().split(/[\s,|]+/);
    return words.some((w: string) => w.length > 1 && msgLower.includes(w));
  });

  return wordMatch ?? null;
}

// ─── Find page in DB by Facebook page ID ─────────────────────────────────────

export async function findPageByFacebookId(
  supabase:       SupabaseClient,
  facebookPageId: string
): Promise<{ id: string; user_id: string; access_token: string; name: string } | null> {
  const { data, error } = await supabase
    .from("pages")
    .select("id, user_id, facebook_page_id, access_token, name, status")
    .eq("facebook_page_id", facebookPageId)
    .eq("status", "active")
    .maybeSingle();

  if (error || !data) return null;

  return data as { id: string; user_id: string; access_token: string; name: string };
}

// ─── Save lead to DB ──────────────────────────────────────────────────────────

export async function saveLead(
  supabase: SupabaseClient,
  pageId:   string,
  name:     string,
  message:  string
): Promise<void> {
  await supabase.from("leads").insert({
    page_id: pageId,
    name,
    message,
  });
}

'@ | Set-Content -Path '.\lib\facebook\matcher.ts' -Encoding UTF8

@'
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

'@ | Set-Content -Path '.\app\api\facebook\connect\route.ts' -Encoding UTF8

@'
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
 * Exchanges code → token → fetches pages → saves to DB → subscribes webhook.
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
      // Upsert page — update if already exists (by facebook_page_id)
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

'@ | Set-Content -Path '.\app\api\facebook\callback\route.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { requireAuth, ApiError } from "@/lib/server-auth";

/**
 * POST /api/facebook/disconnect
 * Disconnects a Facebook page — removes access token, sets status to disconnected.
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

'@ | Set-Content -Path '.\app\api\facebook\disconnect\route.ts' -Encoding UTF8

@'
import { NextResponse } from "next/server";
import { getSupabaseServer } from "@/lib/server-auth";
import { verifyWebhookSignature, sendMessage, getUserProfile } from "@/lib/facebook/graph";
import { findMatchingRule, findPageByFacebookId, saveLead } from "@/lib/facebook/matcher";
import { generateReply, getFallbackReply } from "@/lib/ai/groq";
import { AISettingsService } from "@/lib/db/ai-settings.service";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { canUseAI } from "@/lib/plans";

// ─── Types ────────────────────────────────────────────────────────────────────

type MessagingEvent = {
  sender:    { id: string };
  recipient: { id: string };
  timestamp: number;
  message?:  { mid: string; text: string };
  postback?: { title: string; payload: string };
};

type WebhookEntry = {
  id:        string;
  messaging: MessagingEvent[];
};

type WebhookBody = {
  object:  string;
  entry:   WebhookEntry[];
};

// ─── GET — Facebook webhook verification ─────────────────────────────────────

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);

  const mode      = searchParams.get("hub.mode");
  const token     = searchParams.get("hub.verify_token");
  const challenge = searchParams.get("hub.challenge");

  if (mode === "subscribe" && token === process.env.FACEBOOK_VERIFY_TOKEN) {
    console.log("[Webhook] Facebook verification successful");
    return new Response(challenge, { status: 200 });
  }

  console.warn("[Webhook] Verification failed — check FACEBOOK_VERIFY_TOKEN");
  return NextResponse.json({ error: "Verification failed" }, { status: 403 });
}

// ─── POST — Receive Facebook messages ────────────────────────────────────────

export async function POST(request: Request) {
  try {
    const rawBody  = await request.text();
    const signature = request.headers.get("x-hub-signature-256");

    // 1. Verify signature (skip in dev if APP_SECRET not set)
    if (process.env.FACEBOOK_APP_SECRET) {
      const isValid = await verifyWebhookSignature(rawBody, signature);
      if (!isValid) {
        console.error("[Webhook] Invalid signature — possible spoofed request");
        return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
      }
    }

    const body: WebhookBody = JSON.parse(rawBody);

    // Only handle page messaging events
    if (body.object !== "page") {
      return NextResponse.json({ status: "ignored" });
    }

    const supabase = await getSupabaseServer();

    // Process each entry (each Facebook page)
    for (const entry of body.entry ?? []) {
      for (const event of entry.messaging ?? []) {
        // Only handle real text messages (ignore echoes, deliveries, reads)
        if (!event.message?.text || event.message.text.startsWith("ECHO")) continue;

        // Run in background — don''t block the 200 response
        processMessage(supabase, entry.id, event).catch((err) => {
          console.error("[Webhook] processMessage error:", err);
        });
      }
    }

    // Facebook requires 200 within 20 seconds — always respond fast
    return NextResponse.json({ status: "ok" });
  } catch (err) {
    console.error("[Webhook POST] Error:", err);
    // Return 200 even on error — prevents Facebook from retrying aggressively
    return NextResponse.json({ status: "error" });
  }
}

// ─── Message processing pipeline ──────────────────────────────────────────────

async function processMessage(
  supabase:       Awaited<ReturnType<typeof getSupabaseServer>>,
  facebookPageId: string,
  event:          MessagingEvent
): Promise<void> {
  const senderPsid = event.sender.id;
  const messageText = event.message?.text ?? "";

  console.log(`[Webhook] Message from ${senderPsid} on page ${facebookPageId}: "${messageText}"`);

  // 1. Find page in our DB by Facebook page ID
  const page = await findPageByFacebookId(supabase, facebookPageId);
  if (!page) {
    console.warn(`[Webhook] Page ${facebookPageId} not found in DB — not connected`);
    return;
  }

  if (!page.access_token) {
    console.warn(`[Webhook] Page ${page.name} has no access token`);
    return;
  }

  // 2. Get sender profile for lead capture
  const profileResult = await getUserProfile(senderPsid, page.access_token);
  const senderName    = profileResult.data?.name ?? "Unknown Customer";

  // 3. Save as lead
  await saveLead(supabase, page.id, senderName, messageText);

  // 4. Try automation rules first
  const matchedRule = await findMatchingRule(supabase, page.id, messageText);

  if (matchedRule) {
    console.log(`[Webhook] Matched rule: "${matchedRule.trigger}" → sending reply`);
    await sendMessage(page.access_token, senderPsid, matchedRule.reply);
    return;
  }

  // 5. No rule matched — try AI reply if user has AI plan
  const userPlan = await SubscriptionService.getUserPlan(supabase, page.user_id);

  if (!canUseAI(userPlan)) {
    console.log(`[Webhook] No rule matched, AI not available on ${userPlan} plan`);
    return;
  }

  if (!process.env.GROQ_API_KEY) {
    console.warn("[Webhook] No rule matched and GROQ_API_KEY not set");
    return;
  }

  // 6. Load AI settings for this page
  const { data: aiSettings } = await AISettingsService.get(
    supabase,
    page.user_id,
    page.id
  );

  if (aiSettings && !aiSettings.enabled) {
    console.log(`[Webhook] AI disabled for page ${page.name}`);
    return;
  }

  // 7. Generate AI reply
  console.log(`[Webhook] No rule matched — generating AI reply for: "${messageText}"`);
  const aiResult = await generateReply({
    userMessage:  messageText,
    businessName: aiSettings?.business_name || page.name,
    businessInfo: aiSettings?.business_info || undefined,
    language:     aiSettings?.language      ?? "bangla",
    tone:         aiSettings?.tone          ?? "friendly",
    maxTokens:    250,
  });

  if (aiResult.error) {
    console.error("[Webhook] AI reply failed:", aiResult.error);
    // Send fallback reply so customer isn''t ignored
    const fallback = getFallbackReply(aiSettings?.language ?? "bangla");
    await sendMessage(page.access_token, senderPsid, fallback);
    return;
  }

  await sendMessage(page.access_token, senderPsid, aiResult.reply!);
  console.log(`[Webhook] AI reply sent to ${senderName}`);
}

'@ | Set-Content -Path '.\app\api\webhook\facebook\route.ts' -Encoding UTF8

@'
"use client";

import { useState, useEffect, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import {
  Plus, Search, Globe, Users, MessageCircle,
  MoreVertical, TrendingUp, CheckCircle2,
  RefreshCw, Loader2, Unlink, AlertCircle,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type Page = {
  id:               string;
  name:             string;
  category:         string;
  followers:        number;
  status:           string;
  facebook_page_id: string | null;
  access_token:     string | null;
  created_at:       string;
};

const COLORS = ["indigo", "sky", "amber", "emerald", "purple", "rose"];

const avatarColors: Record<string, string> = {
  indigo:  "from-indigo-600 to-indigo-800",
  sky:     "from-sky-500 to-sky-700",
  amber:   "from-amber-500 to-amber-700",
  emerald: "from-emerald-500 to-emerald-700",
  purple:  "from-purple-500 to-purple-700",
  rose:    "from-rose-500 to-rose-700",
};

const statusStyles: Record<string, string> = {
  active:       "bg-emerald-500/15 text-emerald-400 border-emerald-500/25",
  paused:       "bg-amber-500/15 text-amber-400 border-amber-500/25",
  disconnected: "bg-zinc-800 text-zinc-500 border-zinc-700",
};

function makeAvatar(name: string) {
  return name.split(" ").map((w) => w[0]).join("").toUpperCase().slice(0, 2);
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function PagesPage() {
  const searchParams = useSearchParams();

  const [search,      setSearch]      = useState("");
  const [pages,       setPages]       = useState<Page[]>([]);
  const [loading,     setLoading]     = useState(true);
  const [fetchError,  setFetchError]  = useState<string | null>(null);
  const [notification, setNotification] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [disconnectingId, setDisconnectingId] = useState<string | null>(null);

  // Handle redirect from Facebook OAuth callback
  useEffect(() => {
    const connected = searchParams.get("fb_connected");
    const fbError   = searchParams.get("fb_error");

    if (connected) {
      setNotification({
        type:    "success",
        message: `${connected} Facebook page${Number(connected) > 1 ? "s" : ""} connected successfully!`,
      });
    } else if (fbError) {
      const messages: Record<string, string> = {
        denied:        "Facebook permission denied. Please try again and accept all permissions.",
        token_failed:  "Failed to get Facebook access token. Please try again.",
        pages_failed:  "Could not load your Facebook pages. Make sure you have admin access.",
        no_pages:      "No Facebook pages found. Create a page on Facebook first.",
        server_error:  "Server error during connection. Please try again.",
        missing_params: "Invalid callback parameters. Please try again.",
      };
      setNotification({
        type:    "error",
        message: messages[fbError] ?? "Facebook connection failed. Please try again.",
      });
    }

    // Clear URL params
    if (connected || fbError) {
      window.history.replaceState({}, "", "/dashboard/pages");
    }
  }, [searchParams]);

  const loadPages = useCallback(async () => {
    setLoading(true);
    setFetchError(null);
    try {
      const res  = await fetch("/api/pages", { credentials: "include" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setPages(data.pages ?? []);
    } catch (e: unknown) {
      setFetchError(e instanceof Error ? e.message : "Failed to load pages.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadPages(); }, [loadPages]);

  // Auto-dismiss notification
  useEffect(() => {
    if (!notification) return;
    const t = setTimeout(() => setNotification(null), 5000);
    return () => clearTimeout(t);
  }, [notification]);

  function handleConnectWithFacebook() {
    // Redirect to our OAuth initiation route
    window.location.href = "/api/facebook/connect";
  }

  async function handleDisconnect(pageId: string, pageName: string) {
    if (!confirm(`Disconnect "${pageName}"? Automation will stop for this page.`)) return;

    setDisconnectingId(pageId);
    try {
      const res  = await fetch("/api/facebook/disconnect", {
        method:      "POST",
        credentials: "include",
        headers:     { "Content-Type": "application/json" },
        body:        JSON.stringify({ page_id: pageId }),
      });
      const data = await res.json();

      if (res.ok) {
        setNotification({ type: "success", message: data.message });
        await loadPages();
      } else {
        setNotification({ type: "error", message: data.error ?? "Failed to disconnect." });
      }
    } finally {
      setDisconnectingId(null);
    }
  }

  const filtered = pages.filter((p) =>
    p.name.toLowerCase().includes(search.toLowerCase()) ||
    (p.category ?? "").toLowerCase().includes(search.toLowerCase())
  );

  const activeCount = pages.filter((p) => p.status === "active").length;
  const hasFbCreds  = true; // always show connect button — API handles missing creds

  return (
    <div className="p-8 max-w-6xl animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between mb-8 gap-4 flex-wrap">
        <div>
          <p className="text-xs uppercase tracking-widest text-zinc-600 mb-1">Management</p>
          <h1 className="font-display text-3xl font-700 text-white">Facebook Pages</h1>
          <p className="text-zinc-500 text-sm mt-1">
            {loading ? "Loading..." : `${pages.length} pages connected · ${activeCount} active`}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={loadPages}
            disabled={loading}
            className="p-2.5 glass rounded-xl text-zinc-500 hover:text-zinc-300 border border-white/8 transition-all disabled:opacity-40"
          >
            <RefreshCw size={15} className={loading ? "animate-spin" : ""} />
          </button>
          <button
            onClick={handleConnectWithFacebook}
            className="flex items-center gap-2 px-5 py-2.5 bg-[#1877F2] hover:bg-[#166fe5] text-white text-sm font-semibold rounded-xl transition-all glow-sm"
          >
            <Plus size={16} />
            Connect Facebook Page
          </button>
        </div>
      </div>

      {/* Notification banner */}
      {notification && (
        <div className={`mb-5 flex items-center gap-3 px-4 py-3 rounded-xl text-sm border ${
          notification.type === "success"
            ? "bg-emerald-500/10 border-emerald-500/20 text-emerald-400"
            : "bg-red-500/10 border-red-500/20 text-red-400"
        }`}>
          {notification.type === "success"
            ? <CheckCircle2 size={15} />
            : <AlertCircle size={15} />
          }
          <span>{notification.message}</span>
        </div>
      )}

      {/* Error */}
      {fetchError && (
        <div className="mb-5 flex items-center gap-3 px-4 py-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-400 text-sm">
          <span>⚠</span><span>{fetchError}</span>
        </div>
      )}

      {/* How it works info bar */}
      {pages.length === 0 && !loading && (
        <div className="mb-6 p-5 glass rounded-2xl border border-indigo-500/15 bg-indigo-600/5">
          <h3 className="font-semibold text-white text-sm mb-3">How to connect your Facebook Page</h3>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {[
              { step: "1", title: "Click Connect",     desc: "Click the blue button to start Facebook OAuth" },
              { step: "2", title: "Grant Permission",  desc: "Select your page and accept the required permissions" },
              { step: "3", title: "Auto-reply starts", desc: "Your automation rules and AI start working instantly" },
            ].map((s) => (
              <div key={s.step} className="flex items-start gap-3">
                <div className="w-6 h-6 rounded-full bg-indigo-600 flex items-center justify-center text-xs font-bold text-white flex-shrink-0">
                  {s.step}
                </div>
                <div>
                  <p className="text-xs font-semibold text-zinc-300">{s.title}</p>
                  <p className="text-xs text-zinc-600 mt-0.5">{s.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Search */}
      {pages.length > 0 && (
        <div className="flex items-center gap-3 mb-6">
          <div className="relative flex-1 max-w-sm">
            <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-600" />
            <input
              type="text"
              placeholder="Search pages..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 bg-white/5 border border-white/8 rounded-xl text-sm text-zinc-300 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/40 transition-all"
            />
          </div>
          <div className="flex items-center gap-2">
            {["All", "Active", "Paused"].map((f) => (
              <button key={f} className="px-3.5 py-2 text-xs font-medium rounded-lg glass text-zinc-400 hover:text-zinc-200 hover:bg-white/6 transition-all">
                {f}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Loading skeleton */}
      {loading && (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="glass rounded-2xl p-5 animate-pulse flex flex-col gap-4">
              <div className="flex items-center gap-3">
                <div className="w-11 h-11 rounded-xl bg-white/8" />
                <div className="flex-1 space-y-2">
                  <div className="h-3 bg-white/8 rounded-lg w-2/3" />
                  <div className="h-2.5 bg-white/5 rounded-lg w-1/3" />
                </div>
              </div>
              <div className="grid grid-cols-3 gap-2">
                {[...Array(3)].map((_, j) => <div key={j} className="h-14 bg-white/5 rounded-xl" />)}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Pages grid */}
      {!loading && (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {filtered.map((page, idx) => {
            const color         = COLORS[idx % COLORS.length];
            const isDisconnecting = disconnectingId === page.id;
            const isReal        = !!page.facebook_page_id;

            return (
              <div
                key={page.id}
                className={`glass rounded-2xl p-5 flex flex-col gap-4 transition-all duration-200 group ${
                  page.status === "active" ? "hover:bg-white/4" : "opacity-60 hover:opacity-80"
                }`}
              >
                {/* Top row */}
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className={`w-11 h-11 rounded-xl bg-gradient-to-br ${avatarColors[color]} flex items-center justify-center text-sm font-bold text-white font-display shadow-lg`}>
                      {makeAvatar(page.name)}
                    </div>
                    <div>
                      <p className="font-semibold text-white text-sm leading-tight">{page.name}</p>
                      <p className="text-zinc-600 text-xs mt-0.5">{page.category ?? "Business"}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`text-[11px] font-medium px-2 py-0.5 rounded-full border ${statusStyles[page.status] ?? statusStyles.active} capitalize`}>
                      {page.status}
                    </span>
                    {page.status === "active" && (
                      <button
                        onClick={() => handleDisconnect(page.id, page.name)}
                        disabled={isDisconnecting}
                        className="p-1 rounded-lg text-zinc-700 hover:text-red-400 hover:bg-red-500/10 transition-colors opacity-0 group-hover:opacity-100 disabled:opacity-40"
                        title="Disconnect page"
                      >
                        {isDisconnecting
                          ? <Loader2 size={13} className="animate-spin" />
                          : <Unlink size={13} />
                        }
                      </button>
                    )}
                  </div>
                </div>

                {/* Stats row */}
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { icon: Users,         value: page.followers >= 1000 ? `${(page.followers/1000).toFixed(1)}K` : page.followers, label: "Followers" },
                    { icon: MessageCircle, value: isReal ? "Live"  : "Mock",     label: "Messages"  },
                    { icon: TrendingUp,    value: isReal ? "Real"  : "Demo",     label: "Source"    },
                  ].map(({ icon: Icon, value, label }) => (
                    <div key={label} className="bg-white/4 rounded-xl p-2.5 text-center">
                      <Icon size={12} className="mx-auto mb-1 text-zinc-600" />
                      <p className="text-xs font-semibold text-zinc-300">{value}</p>
                      <p className="text-[10px] text-zinc-600">{label}</p>
                    </div>
                  ))}
                </div>

                {/* Footer */}
                <div className="flex items-center justify-between pt-2 border-t border-white/5">
                  <div className="flex items-center gap-1.5 text-xs text-zinc-600">
                    <Globe size={11} />
                    <span>
                      {page.facebook_page_id
                        ? `fb.com/${page.facebook_page_id}`
                        : "facebook.com/..."}
                    </span>
                  </div>
                  {page.status === "active" && (
                    <div className="flex items-center gap-1 text-xs text-emerald-500">
                      <CheckCircle2 size={11} />
                      <span>{isReal ? "Webhook active" : "AI active"}</span>
                    </div>
                  )}
                </div>
              </div>
            );
          })}

          {/* Empty state */}
          {filtered.length === 0 && pages.length > 0 && (
            <div className="col-span-full text-center py-12 text-zinc-600 text-sm">
              No pages match your search.
            </div>
          )}

          {/* Add CTA card */}
          <button
            onClick={handleConnectWithFacebook}
            className="glass rounded-2xl p-5 border-2 border-dashed border-white/8 hover:border-[#1877F2]/40 hover:bg-[#1877F2]/5 transition-all duration-200 flex flex-col items-center justify-center gap-3 min-h-[200px] group"
          >
            <div className="w-10 h-10 rounded-xl bg-white/5 group-hover:bg-[#1877F2]/20 flex items-center justify-center transition-colors">
              <Plus size={18} className="text-zinc-600 group-hover:text-[#1877F2] transition-colors" />
            </div>
            <div className="text-center">
              <p className="text-sm font-semibold text-zinc-500 group-hover:text-zinc-300 transition-colors">
                Connect another page
              </p>
              <p className="text-xs text-zinc-700 mt-0.5">Via Facebook OAuth</p>
            </div>
          </button>
        </div>
      )}
    </div>
  );
}

'@ | Set-Content -Path '.\app\dashboard\pages\page.tsx' -Encoding UTF8
