import { createBrowserClient } from "@supabase/ssr";

// Singleton — one client instance for the entire browser session.
// Re-creating the client on every render loses the in-memory token cache
// and causes getSession() to return null even when a cookie exists.
let client: ReturnType<typeof createBrowserClient> | null = null;

export function createClient() {
  if (client) return client;

  client = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  return client;
}
