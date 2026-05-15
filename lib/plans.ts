// lib/plans.ts
// Single source of truth for all subscription plans and their limits.
// Used by: pricing page, billing page, API limit checks, middleware.

export type PlanId = "free" | "pro" | "business";

export type Plan = {
  id:            PlanId;
  name:          string;
  price:         number;      // BDT per month
  priceUSD:      number;      // USD per month (for reference)
  pages:         number;      // max connected pages (-1 = unlimited)
  automations:   number;      // max automation rules per page (-1 = unlimited)
  aiReplies:     number;      // max AI replies per month (-1 = unlimited)
  leads:         number;      // max leads stored (-1 = unlimited)
  features:      string[];
  highlighted:   boolean;     // show as "most popular"
  badge?:        string;
};

export const PLANS: Record<PlanId, Plan> = {
  free: {
    id:          "free",
    name:        "Free",
    price:       0,
    priceUSD:    0,
    pages:       1,
    automations: 3,
    aiReplies:   0,
    leads:       50,
    highlighted: false,
    features: [
      "1 Facebook page",
      "3 automation rules",
      "50 leads stored",
      "Basic dashboard",
      "Email support",
    ],
  },

  pro: {
    id:          "pro",
    name:        "Pro",
    price:       799,
    priceUSD:    7,
    pages:       5,
    automations: 25,
    aiReplies:   500,
    leads:       1000,
    highlighted: true,
    badge:       "Most Popular",
    features: [
      "5 Facebook pages",
      "25 automation rules",
      "500 AI replies/month",
      "1,000 leads stored",
      "Bangla + English AI",
      "Priority support",
      "Analytics dashboard",
    ],
  },

  business: {
    id:          "business",
    name:        "Business",
    price:       1999,
    priceUSD:    18,
    pages:       -1,
    automations: -1,
    aiReplies:   -1,
    leads:       -1,
    highlighted: false,
    badge:       "Best Value",
    features: [
      "Unlimited pages",
      "Unlimited automations",
      "Unlimited AI replies",
      "Unlimited leads",
      "Custom AI persona",
      "Webhook integrations",
      "Dedicated support",
      "White-label ready",
    ],
  },
};

export const PLAN_LIST = Object.values(PLANS);

// â”€â”€â”€ Limit checkers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export function canAddPage(plan: PlanId, currentPages: number): boolean {
  const limit = PLANS[plan].pages;
  return limit === -1 || currentPages < limit;
}

export function canAddAutomation(plan: PlanId, currentRules: number): boolean {
  const limit = PLANS[plan].automations;
  return limit === -1 || currentRules < limit;
}

export function canUseAI(plan: PlanId): boolean {
  return PLANS[plan].aiReplies !== 0;
}

export function canAddLead(plan: PlanId, currentLeads: number): boolean {
  const limit = PLANS[plan].leads;
  return limit === -1 || currentLeads < limit;
}

export function formatLimit(value: number): string {
  return value === -1 ? "Unlimited" : value.toLocaleString();
}

