import { NextResponse } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase-server";
import { cookies } from "next/headers";

export async function GET() {
  const cookieStore = await cookies();
  const allCookies = cookieStore.getAll();

  const supabaseCookies = allCookies
    .filter((c) => c.name.startsWith("sb-"))
    .map((c) => c.name);

  const supabase = await createServerSupabaseClient();
  const { data: { user }, error } = await supabase.auth.getUser();

  return NextResponse.json({
    hasUser: !!user,
    userId: user?.id ?? null,
    userEmail: user?.email ?? null,
    authError: error?.message ?? null,
    supabaseCookiesFound: supabaseCookies,
    totalCookies: allCookies.length,
  });
}