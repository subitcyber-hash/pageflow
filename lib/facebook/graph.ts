/**
 * lib/facebook/graph.ts
 * Facebook Graph API client.
 * All Facebook API calls go through this file.
 */

const GRAPH_VERSION = "v19.0";
const GRAPH_BASE    = `https://graph.facebook.com/${GRAPH_VERSION}`;

// â”€â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ OAuth helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Exchange code for user access token â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Get user''s pages â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Subscribe page to webhook â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Send message via Messenger â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Verify webhook signature â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Get user profile from PSID â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

