"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase";
import Link from "next/link";
import { Loader2, Eye, EyeOff, CheckCircle2, AlertCircle } from "lucide-react";

const supabase = createClient();

export default function ResetPasswordPage() {
  const router = useRouter();

  const [password,    setPassword]    = useState("");
  const [confirm,     setConfirm]     = useState("");
  const [showPass,    setShowPass]    = useState(false);
  const [loading,     setLoading]     = useState(false);
  const [done,        setDone]        = useState(false);
  const [error,       setError]       = useState<string | null>(null);
  const [validSession, setValidSession] = useState(false);
  const [checking,    setChecking]    = useState(true);

  useEffect(() => {
    // Supabase puts the recovery token in the URL hash
    // It auto-exchanges it for a session
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event) => {
        if (event === "PASSWORD_RECOVERY") {
          setValidSession(true);
          setChecking(false);
        } else if (event === "SIGNED_IN") {
          setValidSession(true);
          setChecking(false);
        }
      }
    );

    // Fallback — check if already in session
    setTimeout(() => {
      supabase.auth.getSession().then(({ data: { session } }) => {
        if (session) {
          setValidSession(true);
        }
        setChecking(false);
      });
    }, 1000);

    return () => subscription.unsubscribe();
  }, []);

  async function handleReset(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      return;
    }

    if (password !== confirm) {
      setError("Passwords do not match.");
      return;
    }

    setLoading(true);

    const { error } = await supabase.auth.updateUser({ password });

    if (error) {
      setError(error.message);
    } else {
      setDone(true);
      setTimeout(() => {
        router.push("/dashboard");
      }, 2000);
    }

    setLoading(false);
  }

  if (checking) {
    return (
      <div className="animated-gradient min-h-screen flex items-center justify-center">
        <Loader2 size={22} className="animate-spin text-indigo-400" />
      </div>
    );
  }

  return (
    <div className="animated-gradient min-h-screen flex items-center justify-center px-4 relative overflow-hidden">
      <div className="absolute top-[-15%] right-[-5%] w-[500px] h-[500px] bg-indigo-700/10 rounded-full blur-[100px] pointer-events-none" />

      <div className="relative z-10 w-full max-w-md animate-slide-up">
        <div className="text-center mb-8">
          <Link href="/" className="inline-block">
            <span className="font-display text-2xl font-700 gradient-text tracking-tight">PageFlow</span>
          </Link>
          <p className="text-zinc-500 text-sm mt-2">Set a new password</p>
        </div>

        <div className="glass rounded-2xl p-8">
          {done ? (
            <div className="text-center">
              <div className="w-14 h-14 rounded-2xl bg-emerald-600/20 border border-emerald-500/30 flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 size={24} className="text-emerald-400" />
              </div>
              <h2 className="font-display text-xl font-700 text-white mb-2">Password updated!</h2>
              <p className="text-zinc-500 text-sm">Redirecting you to the dashboard...</p>
            </div>
          ) : !validSession ? (
            <div className="text-center">
              <div className="w-14 h-14 rounded-2xl bg-red-600/20 border border-red-500/30 flex items-center justify-center mx-auto mb-4">
                <AlertCircle size={24} className="text-red-400" />
              </div>
              <h2 className="font-display text-xl font-700 text-white mb-2">Link expired</h2>
              <p className="text-zinc-500 text-sm mb-5">
                This reset link has expired or already been used. Request a new one.
              </p>
              <Link
                href="/auth/forgot-password"
                className="inline-block w-full py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-semibold rounded-xl transition-all text-sm text-center"
              >
                Request new link
              </Link>
            </div>
          ) : (
            <>
              <div className="mb-6">
                <h2 className="font-display text-xl font-700 text-white">Set new password</h2>
                <p className="text-zinc-500 text-sm mt-1">
                  Choose a strong password for your account.
                </p>
              </div>

              <form onSubmit={handleReset} className="space-y-4">
                {/* New password */}
                <div>
                  <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                    New Password
                  </label>
                  <div className="relative">
                    <input
                      type={showPass ? "text" : "password"}
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Min 6 characters"
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
                </div>

                {/* Confirm password */}
                <div>
                  <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                    Confirm Password
                  </label>
                  <input
                    type={showPass ? "text" : "password"}
                    required
                    value={confirm}
                    onChange={(e) => setConfirm(e.target.value)}
                    placeholder="Repeat password"
                    className="w-full bg-white/5 border border-white/8 rounded-xl px-4 py-3 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500/50 transition-all"
                  />
                </div>

                {/* Password strength indicator */}
                {password.length > 0 && (
                  <div className="flex items-center gap-2">
                    <div className="flex gap-1 flex-1">
                      {[1, 2, 3, 4].map((i) => (
                        <div
                          key={i}
                          className={`h-1 flex-1 rounded-full transition-all ${
                            password.length >= i * 3
                              ? i <= 2 ? "bg-amber-500" : "bg-emerald-500"
                              : "bg-white/10"
                          }`}
                        />
                      ))}
                    </div>
                    <span className="text-xs text-zinc-600">
                      {password.length < 6 ? "Too short" :
                       password.length < 9 ? "Weak" :
                       password.length < 12 ? "Good" : "Strong"}
                    </span>
                  </div>
                )}

                {error && (
                  <div className="flex items-start gap-2.5 p-3.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
                    <span className="flex-shrink-0 mt-0.5">!</span>
                    <span>{error}</span>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full py-3 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-semibold rounded-xl transition-all text-sm flex items-center justify-center gap-2"
                >
                  {loading ? (
                    <><Loader2 size={15} className="animate-spin" /> Updating...</>
                  ) : (
                    "Update password"
                  )}
                </button>
              </form>
            </>
          )}
        </div>
      </div>
    </div>
  );
}