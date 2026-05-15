"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase";
import Link from "next/link";
import { Loader2, ArrowLeft, Mail, CheckCircle2 } from "lucide-react";

const supabase = createClient();

export default function ForgotPasswordPage() {
  const [email,   setEmail]   = useState("");
  const [loading, setLoading] = useState(false);
  const [sent,    setSent]    = useState(false);
  const [error,   setError]   = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);

    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/reset-password`,
    });

    if (error) {
      setError(error.message);
    } else {
      setSent(true);
    }

    setLoading(false);
  }

  return (
    <div className="animated-gradient min-h-screen flex items-center justify-center px-4 relative overflow-hidden">
      <div className="absolute top-[-15%] right-[-5%] w-[500px] h-[500px] bg-indigo-700/10 rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute bottom-[-10%] left-[-5%] w-[400px] h-[400px] bg-purple-700/10 rounded-full blur-[100px] pointer-events-none" />

      <div className="relative z-10 w-full max-w-md animate-slide-up">
        <div className="text-center mb-8">
          <Link href="/" className="inline-block">
            <span className="font-display text-2xl font-700 gradient-text tracking-tight">PageFlow</span>
          </Link>
          <p className="text-zinc-500 text-sm mt-2">Reset your password</p>
        </div>

        <div className="glass rounded-2xl p-8">
          {sent ? (
            /* Success state */
            <div className="text-center">
              <div className="w-14 h-14 rounded-2xl bg-emerald-600/20 border border-emerald-500/30 flex items-center justify-center mx-auto mb-4">
                <CheckCircle2 size={24} className="text-emerald-400" />
              </div>
              <h2 className="font-display text-xl font-700 text-white mb-2">Check your email</h2>
              <p className="text-zinc-500 text-sm mb-6">
                We sent a password reset link to{" "}
                <span className="text-zinc-300 font-medium">{email}</span>.
                Click the link in the email to reset your password.
              </p>
              <p className="text-zinc-600 text-xs mb-5">
                Did not receive it? Check your spam folder or try again.
              </p>
              <button
                onClick={() => { setSent(false); setEmail(""); }}
                className="w-full py-2.5 glass border border-white/8 text-zinc-400 hover:text-zinc-200 text-sm font-medium rounded-xl transition-all"
              >
                Try again
              </button>
            </div>
          ) : (
            /* Form state */
            <>
              <div className="mb-6">
                <div className="w-12 h-12 rounded-xl bg-indigo-600/20 border border-indigo-500/30 flex items-center justify-center mb-4">
                  <Mail size={20} className="text-indigo-400" />
                </div>
                <h2 className="font-display text-xl font-700 text-white">Forgot your password?</h2>
                <p className="text-zinc-500 text-sm mt-1">
                  Enter your email and we will send you a reset link.
                </p>
              </div>

              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-zinc-400 mb-1.5 uppercase tracking-wider">
                    Email address
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
                    <><Loader2 size={15} className="animate-spin" /> Sending...</>
                  ) : (
                    "Send reset link"
                  )}
                </button>
              </form>
            </>
          )}
        </div>

        <div className="text-center mt-6">
          <Link
            href="/auth"
            className="inline-flex items-center gap-2 text-zinc-600 hover:text-zinc-400 text-xs transition-colors"
          >
            <ArrowLeft size={12} />
            Back to sign in
          </Link>
        </div>
      </div>
    </div>
  );
}