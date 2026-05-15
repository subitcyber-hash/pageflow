import { NextResponse } from "next/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { verifyWebhookSignature, sendMessage, getUserProfile } from "@/lib/facebook/graph";
import { findMatchingRule, findPageByFacebookId, saveLead } from "@/lib/facebook/matcher";
import { generateReply, getFallbackReply } from "@/lib/ai/groq";
import { AISettingsService } from "@/lib/db/ai-settings.service";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { canUseAI } from "@/lib/plans";

// ─── Service role client (bypasses RLS for server-to-server webhook) ──────────
// Facebook webhook requests have no user session/cookies.
// We must use the service role key to read pages, automations, leads.
// NEVER expose this key to the browser — this file runs server-side only.

function getServiceClient() {
  const url     = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const svcKey  = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  // Use service role if available (bypasses RLS), otherwise fall back to anon
  return createClient(url, svcKey ?? anonKey, {
    auth: { persistSession: false },
  });
}

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
    const rawBody   = await request.text();
    const signature = request.headers.get("x-hub-signature-256");

    // Verify signature (skip if APP_SECRET not set in dev)
    if (process.env.FACEBOOK_APP_SECRET) {
      const isValid = await verifyWebhookSignature(rawBody, signature);
      if (!isValid) {
        console.error("[Webhook] Invalid signature");
        return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
      }
    }

    const body: WebhookBody = JSON.parse(rawBody);

    if (body.object !== "page") {
      return NextResponse.json({ status: "ignored" });
    }

    // Use service role client — no user session in webhook requests
    const supabase = getServiceClient();

    for (const entry of body.entry ?? []) {
      for (const event of entry.messaging ?? []) {
        if (!event.message?.text) continue;

        // Process in background — don't block the 200 response
        processMessage(supabase, entry.id, event).catch((err) => {
          console.error("[Webhook] processMessage error:", err);
        });
      }
    }

    // Always return 200 fast — Facebook requires response within 20 seconds
    return NextResponse.json({ status: "ok" });
  } catch (err) {
    console.error("[Webhook POST] Error:", err);
    return NextResponse.json({ status: "error" });
  }
}

// ─── Message processing pipeline ─────────────────────────────────────────────

async function processMessage(
  supabase:       SupabaseClient,
  facebookPageId: string,
  event:          MessagingEvent
): Promise<void> {
  const senderPsid  = event.sender.id;
  const messageText = event.message?.text ?? "";

  console.log(`[Webhook] Message from ${senderPsid} on page ${facebookPageId}: "${messageText}"`);

  // 1. Find page in DB
  const page = await findPageByFacebookId(supabase, facebookPageId);
  if (!page) {
    console.warn(`[Webhook] Page ${facebookPageId} not found in DB — connect it via dashboard`);
    return;
  }

  if (!page.access_token) {
    console.warn(`[Webhook] Page "${page.name}" has no access token — reconnect via dashboard`);
    return;
  }

  // 2. Get sender name for lead capture
  const profileResult = await getUserProfile(senderPsid, page.access_token);
  const senderName    = profileResult.data?.name ?? "Unknown Customer";

  // 3. Save as lead
  await saveLead(supabase, page.id, senderName, messageText);
  console.log(`[Webhook] Lead saved: ${senderName}`);

  // 4. Try automation rules first
  const matchedRule = await findMatchingRule(supabase, page.id, messageText);

  if (matchedRule) {
    console.log(`[Webhook] Rule matched: "${matchedRule.trigger}" → sending reply`);
    const result = await sendMessage(page.access_token, senderPsid, matchedRule.reply);
    if (result.error) {
      console.error(`[Webhook] Failed to send rule reply: ${result.error}`);
    } else {
      console.log(`[Webhook] Rule reply sent to ${senderName} ✅`);
    }
    return;
  }

  console.log(`[Webhook] No rule matched for: "${messageText}"`);

  // 5. Try AI reply if plan allows
  const userPlan = await SubscriptionService.getUserPlan(supabase, page.user_id);

  if (!canUseAI(userPlan)) {
    console.log(`[Webhook] AI not available on ${userPlan} plan`);
    return;
  }

  if (!process.env.GROQ_API_KEY) {
    console.warn("[Webhook] GROQ_API_KEY not set — skipping AI reply");
    return;
  }

  // 6. Load AI settings
  const { data: aiSettings } = await AISettingsService.get(
    supabase,
    page.user_id,
    page.id
  );

  if (aiSettings && !aiSettings.enabled) {
    console.log(`[Webhook] AI disabled for page "${page.name}"`);
    return;
  }

  // 7. Generate AI reply
  console.log(`[Webhook] Generating AI reply for: "${messageText}"`);
  const aiResult = await generateReply({
    userMessage:  messageText,
    businessName: aiSettings?.business_name || page.name,
    businessInfo: aiSettings?.business_info || undefined,
    language:     aiSettings?.language      ?? "bangla",
    tone:         aiSettings?.tone          ?? "friendly",
    maxTokens:    250,
  });

  if (aiResult.error) {
    console.error(`[Webhook] AI error: ${aiResult.error}`);
    const fallback = getFallbackReply(aiSettings?.language ?? "bangla");
    await sendMessage(page.access_token, senderPsid, fallback);
    return;
  }

  const result = await sendMessage(page.access_token, senderPsid, aiResult.reply!);
  if (result.error) {
    console.error(`[Webhook] Failed to send AI reply: ${result.error}`);
  } else {
    console.log(`[Webhook] AI reply sent to ${senderName} ✅`);
  }
}