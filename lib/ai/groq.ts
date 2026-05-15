/**
 * lib/ai/groq.ts
 * Groq AI integration for smart reply generation.
 * Supports Bangla + English, multiple tones.
 */

// ─── Types ────────────────────────────────────────────────────────────────────

export type GenerateReplyInput = {
  userMessage:   string;
  businessName?: string;
  businessInfo?: string;  // e.g. "We sell clothes. Prices start at 500tk"
  persona?:      string;  // custom opening greeting
  language?:     "bangla" | "english" | "mixed";
  tone?:         "friendly" | "professional" | "casual";
  maxTokens?:    number;
};

export type GenerateReplyResult =
  | { reply: string; error: null;   tokensUsed: number }
  | { reply: null;   error: string; tokensUsed: 0 };

// ─── Client ───────────────────────────────────────────────────────────────────

function getGroqApiKey(): string {
  const key = process.env.GROQ_API_KEY;
  if (!key) throw new Error("GROQ_API_KEY is not set in environment variables");
  return key;
}

// ─── Main function ────────────────────────────────────────────────────────────

export async function generateReply(
  input: GenerateReplyInput
): Promise<GenerateReplyResult> {
  try {
    const apiKey = getGroqApiKey();

    const languageInstruction =
      input.language === "bangla"
        ? "Always reply in Bangla (Bengali script). Use natural conversational Bangla."
        : input.language === "mixed"
        ? "Reply in a mix of Bangla and English (Banglish style), natural for Bangladeshi users."
        : "Reply in English.";

    const toneInstruction =
      input.tone === "professional"
        ? "Use a professional and formal tone."
        : input.tone === "casual"
        ? "Use a casual, relaxed tone like talking to a friend."
        : "Use a friendly, warm, and helpful tone. Use emojis occasionally.";

    const systemPrompt = [
      `You are a customer service assistant for a Facebook business page.`,
      input.businessName
        ? `Business name: ${input.businessName}`
        : "",
      input.businessInfo
        ? `Business info: ${input.businessInfo}`
        : "",
      languageInstruction,
      toneInstruction,
      `Keep replies concise (2-4 sentences max).`,
      `Do not use markdown formatting.`,
      `If you don't know something specific, offer to help or ask the customer to inbox for details.`,
    ]
      .filter(Boolean)
      .join("\n");

    const response = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model:       "llama-3.1-8b-instant",
          max_tokens:  input.maxTokens ?? 300,
          temperature: 0.7,
          messages: [
            { role: "system", content: systemPrompt          },
            { role: "user",   content: input.userMessage     },
          ],
        }),
      }
    );

    if (!response.ok) {
      const errData = await response.json().catch(() => ({}));
      const errMsg = (errData as { error?: { message?: string } })?.error?.message ?? `Groq API error: ${response.status}`;
      console.error("[Groq] API error:", errMsg);
      return { reply: null, error: errMsg, tokensUsed: 0 };
    }

    const data = await response.json() as {
      choices: { message: { content: string } }[];
      usage:   { total_tokens: number };
    };

    const reply = data.choices?.[0]?.message?.content?.trim();
    if (!reply) {
      return { reply: null, error: "Empty response from Groq", tokensUsed: 0 };
    }

    return {
      reply,
      error:      null,
      tokensUsed: data.usage?.total_tokens ?? 0,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown AI error";
    console.error("[Groq] generateReply error:", message);
    return { reply: null, error: message, tokensUsed: 0 };
  }
}

// ─── Test reply (used when GROQ_API_KEY not set) ──────────────────────────────

export function getFallbackReply(language: string = "english"): string {
  if (language === "bangla" || language === "mixed") {
    return "ধন্যবাদ আপনার মেসেজের জন্য! আমরা শীঘ্রই আপনার সাথে যোগাযোগ করব। 😊";
  }
  return "Thank you for your message! We will get back to you shortly. 😊";
}