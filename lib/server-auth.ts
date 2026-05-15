import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import type { SupabaseClient, User } from "@supabase/supabase-js";

// â”€â”€â”€ Supabase server instance â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export async function getSupabaseServer(): Promise<SupabaseClient> {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {
            // Read-only in Server Components â€” safe to ignore
          }
        },
      },
    }
  );
}

// â”€â”€â”€ Auth guard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Returns authenticated user or throws a 401 NextResponse.
// Usage:
//   const { user, supabase } = await requireAuth();

export type AuthContext = {
  user: User;
  supabase: SupabaseClient;
};

export async function requireAuth(): Promise<AuthContext> {
  const supabase = await getSupabaseServer();

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error || !user) {
    // Throw a Response so API routes can return it directly:
    //   const auth = await requireAuth().catch((r) => r);
    //   if (auth instanceof Response) return auth;
    throw NextResponse.json(
      { error: "Unauthorized", code: "AUTH_REQUIRED" },
      { status: 401 }
    );
  }

  return { user, supabase };
}

// â”€â”€â”€ Standard error responses â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export const ApiError = {
  unauthorized: () =>
    NextResponse.json({ error: "Unauthorized", code: "AUTH_REQUIRED" }, { status: 401 }),

  forbidden: () =>
    NextResponse.json({ error: "Forbidden", code: "ACCESS_DENIED" }, { status: 403 }),

  notFound: (resource = "Resource") =>
    NextResponse.json({ error: `${resource} not found`, code: "NOT_FOUND" }, { status: 404 }),

  badRequest: (message: string) =>
    NextResponse.json({ error: message, code: "BAD_REQUEST" }, { status: 400 }),

  internal: (message = "Internal server error") =>
    NextResponse.json({ error: message, code: "INTERNAL_ERROR" }, { status: 500 }),
};

// â”€â”€â”€ Input sanitization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export function sanitizeString(value: unknown, maxLength = 255): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) return null;
  return trimmed;
}

