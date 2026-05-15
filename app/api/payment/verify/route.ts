import { NextResponse } from "next/server";
import { getSupabaseServer } from "@/lib/server-auth";
import { SubscriptionService } from "@/lib/db/subscription.service";
import { PLANS, type PlanId } from "@/lib/plans";

/**
 * GET /api/payment/verify
 * Called by SSLCommerz as success/fail/cancel redirect.
 * Also handles IPN (Instant Payment Notification) via POST.
 */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const status  = searchParams.get("status");
  const tranId  = searchParams.get("tran_id");
  const planId  = searchParams.get("plan") as PlanId | null;
  const userId  = searchParams.get("user_id");
  const isMock  = searchParams.get("mock") === "true";

  const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

  if (status !== "success" || !tranId || !planId || !userId) {
    return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=failed`);
  }

  try {
    const supabase = await getSupabaseServer();
    const plan     = PLANS[planId];

    if (!plan || planId === "free") {
      return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=invalid`);
    }

    // For mock payments (dev mode) â€” skip SSLCommerz verification
    if (!isMock) {
      const storeId   = process.env.SSLCOMMERZ_STORE_ID;
      const storePass = process.env.SSLCOMMERZ_STORE_PASSWORD;
      const isSandbox = process.env.SSLCOMMERZ_SANDBOX === "true";

      if (storeId && storePass) {
        // Verify transaction with SSLCommerz
        const verifyUrl = isSandbox
          ? `https://sandbox.sslcommerz.com/validator/api/validationserverAPI.php`
          : `https://securepay.sslcommerz.com/validator/api/validationserverAPI.php`;

        const verifyRes = await fetch(
          `${verifyUrl}?val_id=${tranId}&store_id=${storeId}&store_passwd=${storePass}&format=json`
        );
        const verifyData = await verifyRes.json() as {
          status: string;
          amount: string;
          currency_type: string;
        };

        if (verifyData.status !== "VALID" && verifyData.status !== "VALIDATED") {
          console.error("[Verify] Invalid transaction:", tranId);
          return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=invalid`);
        }
      }
    }

    // Create subscription in DB
    const { error } = await SubscriptionService.create(supabase, userId, {
      plan:           planId,
      transaction_id: tranId,
      amount:         plan.price,
      payment_method: isMock ? "mock" : "sslcommerz",
    });

    if (error) {
      console.error("[Verify] Subscription create failed:", error.message);
      return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=error`);
    }

    return NextResponse.redirect(
      `${baseUrl}/dashboard/billing?payment=success&plan=${planId}`
    );
  } catch (err) {
    console.error("[GET /api/payment/verify]", err);
    return NextResponse.redirect(`${baseUrl}/dashboard/billing?payment=error`);
  }
}

/**
 * POST /api/payment/verify
 * IPN handler â€” SSLCommerz calls this server-to-server to confirm payment.
 */
export async function POST(request: Request) {
  try {
    const body = await request.formData();
    const status  = body.get("status")?.toString();
    const tranId  = body.get("tran_id")?.toString();
    const amount  = body.get("amount")?.toString();
    const valId   = body.get("val_id")?.toString();

    console.log("[IPN] Received:", { status, tranId, amount, valId });

    // TODO: Validate IPN signature and update subscription status
    // This is called server-to-server, not by the user

    return NextResponse.json({ status: "ok" });
  } catch (err) {
    console.error("[POST /api/payment/verify]", err);
    return NextResponse.json({ status: "error" });
  }
}

