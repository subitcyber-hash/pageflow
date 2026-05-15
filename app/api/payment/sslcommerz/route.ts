import { NextResponse } from "next/server";
import { requireAuth, ApiError, sanitizeString } from "@/lib/server-auth";
import { PLANS, type PlanId } from "@/lib/plans";

/**
 * POST /api/payment/sslcommerz
 * Initiates a payment session with SSLCommerz.
 * Body: { plan_id: "pro" | "business" }
 *
 * SSLCommerz flow:
 * 1. Client calls this endpoint
 * 2. We call SSLCommerz API to create a session
 * 3. Return the payment URL
 * 4. Client redirects to SSLCommerz payment page
 * 5. SSLCommerz redirects back to /api/payment/verify
 */
export async function POST(request: Request) {
  try {
    const { user } = await requireAuth().catch((r) => { throw r; });

    let body: Record<string, unknown>;
    try {
      body = await request.json();
    } catch {
      return ApiError.badRequest("Invalid JSON body");
    }

    const planId = sanitizeString(body.plan_id) as PlanId | null;
    if (!planId || !["pro", "business"].includes(planId)) {
      return ApiError.badRequest("plan_id must be ''pro'' or ''business''");
    }

    const plan = PLANS[planId];
    const storeId  = process.env.SSLCOMMERZ_STORE_ID;
    const storePass = process.env.SSLCOMMERZ_STORE_PASSWORD;
    const isSandbox = process.env.SSLCOMMERZ_SANDBOX === "true";

    if (!storeId || !storePass) {
      // Return mock response in development
      console.warn("[SSLCommerz] Credentials not set â€” returning mock payment URL");
      return NextResponse.json({
        success:     true,
        paymentUrl:  `${process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000"}/dashboard/billing?mock=true&plan=${planId}`,
        mock:        true,
        message:     "Add SSLCOMMERZ_STORE_ID and SSLCOMMERZ_STORE_PASSWORD to .env.local for real payments",
      });
    }

    const transactionId = `PF-${Date.now()}-${user.id.slice(0, 8)}`;
    const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

    const params = new URLSearchParams({
      store_id:          storeId,
      store_passwd:      storePass,
      total_amount:      plan.price.toString(),
      currency:          "BDT",
      tran_id:           transactionId,
      success_url:       `${baseUrl}/api/payment/verify?status=success&tran_id=${transactionId}&plan=${planId}&user_id=${user.id}`,
      fail_url:          `${baseUrl}/api/payment/verify?status=fail`,
      cancel_url:        `${baseUrl}/dashboard/billing?cancelled=true`,
      ipn_url:           `${baseUrl}/api/payment/verify`,
      product_name:      `PageFlow ${plan.name} Plan`,
      product_category:  "SaaS Subscription",
      product_profile:   "non-physical-goods",
      cus_name:          user.email?.split("@")[0] ?? "Customer",
      cus_email:         user.email ?? "",
      cus_phone:         "01XXXXXXXXX",
      cus_add1:          "Dhaka",
      cus_city:          "Dhaka",
      cus_country:       "Bangladesh",
      shipping_method:   "NO",
      num_of_item:       "1",
      weight_of_items:   "0",
      amount_per_item:   plan.price.toString(),
    });

    const apiUrl = isSandbox
      ? "https://sandbox.sslcommerz.com/gwprocess/v4/api.php"
      : "https://securepay.sslcommerz.com/gwprocess/v4/api.php";

    const response = await fetch(apiUrl, {
      method:  "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:    params.toString(),
    });

    const data = await response.json() as {
      status: string;
      GatewayPageURL?: string;
      failedreason?: string;
    };

    if (data.status !== "SUCCESS" || !data.GatewayPageURL) {
      console.error("[SSLCommerz] Init failed:", data.failedreason);
      return ApiError.internal(data.failedreason ?? "Payment initialization failed");
    }

    return NextResponse.json({
      success:    true,
      paymentUrl: data.GatewayPageURL,
      tran_id:    transactionId,
    });
  } catch (err) {
    if (err instanceof Response) return err;
    console.error("[POST /api/payment/sslcommerz]", err);
    return ApiError.internal();
  }
}

