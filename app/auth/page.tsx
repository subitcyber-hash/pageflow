"use client";

import { useState, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase";
import Link from "next/link";
import { Eye, EyeOff, Loader2 } from "lucide-react";

// Client created once at module level — uses singleton, session is preserved.
const supabase = createClient();

export default function AuthPage() {
  const router       = useRouter();
  const searchParams = useSearchParams();

  const [mode, setMode]         = useState<"login" | "signup">("login");
  const [email, setEmail]       = useState("");
  const [password, setPassword] = useState("");
  const [showPass, setShowPass] = useState(false);
  const [loading,       setLoading]       = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [checking,      setChecking]      = useState(true); // checking existing session
  const [error, setError]       = useState<string | null>(null);
  const [success, setSuccess]   = useState<string | null>(null);

  // Handle ?error= from auth callback route
  useEffect(() => {
    const cbError = searchParams.get("error");
    if (cbError) {
      setError(
        cbError === "auth_callback_error"
          ? "Confirmation link expired or invalid. Please sign in again."
          : decodeURIComponent(cbError)
      );
    }
  }, [searchParams]);

  // Check for existing session on mount — redirect immediately if logged in.
  // Use getUser() not getSession(): getUser() hits Supabase to validate the
  // JWT so we know for certain the session is real.
  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        router.replace("/dashboard");
      } else {
        setChecking(false);
      }
    });
  }, [router]);

  async function handleGoogleSignIn() {
    setGoogleLoading(true);
    setError(null);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) {
      setError(error.message);
      setGoogleLoading(false);
    }
    // On success, browser redirects to Google — no need to setLoading(false)
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(null);

    if (mode === "login") {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        setError(
          error.message === "Invalid login credentials"
            ? "Incorrect email or password. Please try again."
            : error.message
        );
        setLoading(false);
        return;
      }

      if (data.session) {
        // Session is now stored in cookie by the browser client.
        router.push("/dashboard");
        router.refresh();
      }
    } else {
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
        },
      });

      if (error) {
        setError(error.message);
      } else {
        setSuccess(
          "Account created! Check your email for a confirmation link, then sign in."
        );
        setMode("login");
        setPassword("");
      }
    }

    setLoading(false);
  }

  function switchMode(m: "login" | "signup") {
    setMode(m);
    setError(null);
    setSuccess(null);
  }

  // While verifying existing session, show nothing (avoids flash)
  if (checking) {
    return (
      <div className="min-h-screen animated-gradient flex items-center justify-center">
        <Loader2 size={22} className="animate-spin text-indigo-400" />
      </div>
    );
  }

  return (
    <div className="animated-gradient min-h-screen flex items-center justify-center px-4 relative overflow-hidden">
      {/* Orbs */}
      <div className="absolute top-[-15%] right-[-5%] w-[500px] h-[500px] bg-indigo-700/10 rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute bottom-[-10%] left-[-5%] w-[400px] h-[400px] bg-purple-700/10 rounded-full blur-[100px] pointer-events-none" />

      <div className="relative z-10 w-full max-w-md animate-slide-up">
        {/* Logo */}
        <div className="text-center mb-8">
          <Link href="/" className="inline-block">
            <span className="font-display text-2xl font-700 gradient-text tracking-tight">
              PageFlow
            </span>
          </Link>
          <p className="text-zinc-500 text-sm mt-2">
            {mode === "login" ? "Sign in to your workspace" : "Create your free account"}
          </p>
        </div>

        {/* Card */}
        <div className="glass rounded-2xl p-8">
          {/* Tab toggle */}
          <div className="flex gap-1 p-1 bg-white/5 rounded-xl mb-7">
            {(["login", "signup"] as const).map((m) => (
              <button
                key={m}
                type="button"
                onClick={() => switchMode(m)}
                className={`flex-1 py-2 text-sm font-semibold rounded-lg transition-all duration-200 ${
                  mode === m
                    ? "bg-indigo-600 text-white shadow"
                    : "text-zinc-400 hover:text-zinc-200"
                }`}
              >
                {m === "login" ? "Sign In" : "Sign Up"}
              </button>
            ))}
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Email */}
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                Email
              </label>
              <input
                type="email"
                required
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@company.com"
                className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all"
              />
            </div>

            {/* Password */}
            <div>
              <div className="flex items-center justify-between mb-1.5">
                <label className="block text-xs font-medium text-zinc-400 uppercase tracking-wider">
                  Password
                </label>
                {mode === "login" && (
                  <Link
                    href="/auth/forgot-password"
                    className="text-xs text-zinc-600 hover:text-indigo-400 transition-colors"
                  >
                    Forgot password?
                  </Link>
                )}
              </div>
              <div className="relative">
                <input
                  type={showPass ? "text" : "password"}
                  required
                  autoComplete={mode === "login" ? "current-password" : "new-password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  minLength={6}
                  className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 pr-11 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all"
                />
                <button
                  type="button"
                  onClick={() => setShowPass(!showPass)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-zinc-600 hover:text-zinc-400 transition-colors"
                >
                  {showPass ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
              {mode === "signup" && (
                <p className="text-xs text-zinc-700 mt-1.5">Minimum 6 characters</p>
              )}
            </div>

            {/* Error */}
            {error && (
              <div className="flex items-start gap-2.5 p-3.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
                <span className="mt-0.5 flex-shrink-0">⚠</span>
                <span>{error}</span>
              </div>
            )}

            {/* Success */}
            {success && (
              <div className="flex items-start gap-2.5 p-3.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm">
                <span className="mt-0.5 flex-shrink-0">✓</span>
                <span>{success}</span>
              </div>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold rounded-xl transition-all duration-200 text-sm tracking-wide glow-sm flex items-center justify-center gap-2"
            >
              {loading ? (
                <>
                  <Loader2 size={15} className="animate-spin" />
                  Please wait…
                </>
              ) : mode === "login" ? (
                "Sign In →"
              ) : (
                "Create Account →"
              )}
            </button>
          </form>

          {/* Divider */}
          <div className="flex items-center gap-3 my-5">
            <div className="flex-1 h-px bg-white/8" />
            <span className="text-xs text-zinc-600 font-medium">or continue with</span>
            <div className="flex-1 h-px bg-white/8" />
          </div>

          {/* Google Sign In */}
          <button
            type="button"
            onClick={handleGoogleSignIn}
            disabled={googleLoading || loading}
            className="w-full flex items-center justify-center gap-3 py-3 glass border border-white/10 hover:bg-white/6 hover:border-white/20 text-zinc-300 font-semibold rounded-xl transition-all text-sm disabled:opacity-50"
          >
            {googleLoading ? (
              <Loader2 size={16} className="animate-spin" />
            ) : (
              <svg width="18" height="18" viewBox="0 0 24 24">
                <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
              </svg>
            )}
            {googleLoading ? "Redirecting..." : "Continue with Google"}
          </button>

          <p className="text-center text-zinc-600 text-xs mt-5">
            By continuing you agree to our{" "}
            <span className="text-zinc-500 hover:text-zinc-300 cursor-pointer transition-colors">
              Terms
            </span>{" "}
            &amp;{" "}
            <span className="text-zinc-500 hover:text-zinc-300 cursor-pointer transition-colors">
              Privacy Policy
            </span>
          </p>
        </div>

        <p className="text-center text-zinc-600 text-xs mt-6">
          <Link href="/" className="hover:text-zinc-400 transition-colors">
            ← Back to home
          </Link>
        </p>
      </div>
    </div>
  );
}