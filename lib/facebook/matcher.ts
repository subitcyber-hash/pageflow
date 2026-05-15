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

// â”€â”€â”€ Find matching automation rule â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Find page in DB by Facebook page ID â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Save lead to DB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

