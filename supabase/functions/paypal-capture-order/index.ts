// PayPal REST API — Capture Order
// Called after user approves payment on PayPal, captures the funds
// and activates premium subscription
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PAYPAL_CLIENT_ID = Deno.env.get("PAYPAL_CLIENT_ID")!;
const PAYPAL_CLIENT_SECRET = Deno.env.get("PAYPAL_CLIENT_SECRET")!;
const PAYPAL_ENV = Deno.env.get("PAYPAL_ENV") || "sandbox";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const BASE_URL =
  PAYPAL_ENV === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";

async function getAccessToken(): Promise<string> {
  const credentials = btoa(`${PAYPAL_CLIENT_ID}:${PAYPAL_CLIENT_SECRET}`);
  const response = await fetch(`${BASE_URL}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    throw new Error(`PayPal auth failed: ${response.statusText}`);
  }

  const data = await response.json();
  return data.access_token;
}

Deno.serve(async (req) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers":
          "Content-Type, Authorization, apikey, x-client-info",
      },
    });
  }

  try {
    const { order_id } = await req.json();

    if (!order_id) {
      return new Response(
        JSON.stringify({ error: "Missing order_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const accessToken = await getAccessToken();

    // Capture the PayPal order (actually charge the customer)
    const captureResponse = await fetch(
      `${BASE_URL}/v2/checkout/orders/${order_id}/capture`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
      }
    );

    const captureData = await captureResponse.json();

    if (captureData.status !== "COMPLETED") {
      console.error("PayPal capture not completed:", captureData);
      return new Response(
        JSON.stringify({
          error: "Payment capture failed",
          details: captureData.details || captureData.message,
        }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    // Extract capture details
    const capture =
      captureData.purchase_units?.[0]?.payments?.captures?.[0];
    const transactionId = capture?.id || order_id;
    const capturedAmount = parseFloat(capture?.amount?.value || "0");
    const currency = capture?.amount?.currency_code || "USD";

    // Get the custom_id which has family_id and months
    const customId = captureData.purchase_units?.[0]?.payments?.captures?.[0]?.custom_id
      || captureData.purchase_units?.[0]?.custom_id;

    let familyId: string | null = null;
    let months = 1;

    if (customId) {
      try {
        const parsed = JSON.parse(customId);
        familyId = parsed.family_id;
        months = parsed.months || 1;
      } catch {
        // custom_id might just be the family_id
        familyId = customId;
      }
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // If we couldn't get family_id from custom_id, look it up from pending orders
    if (!familyId) {
      const { data: pendingOrder } = await supabase
        .from("paypal_pending")
        .select("family_id, months")
        .eq("order_id", order_id)
        .single();

      if (pendingOrder) {
        familyId = pendingOrder.family_id;
        months = pendingOrder.months || months;
      }
    }

    if (!familyId) {
      return new Response(
        JSON.stringify({ error: "Could not determine family for this payment" }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    // Update pending order status
    await supabase
      .from("paypal_pending")
      .update({ status: "completed", transaction_id: transactionId })
      .eq("order_id", order_id);

    // Check if there's an existing active subscription to extend
    const now = new Date();
    const { data: existingSub } = await supabase
      .from("subscriptions")
      .select("expires_at")
      .eq("family_id", familyId)
      .eq("plan", "premium")
      .gt("expires_at", now.toISOString())
      .order("expires_at", { ascending: false })
      .limit(1);

    let startFrom = now;
    if (existingSub && existingSub.length > 0) {
      const existingExpiry = new Date(existingSub[0].expires_at);
      if (existingExpiry > now) {
        startFrom = existingExpiry;
      }
    }

    const expiresAt = new Date(startFrom);
    expiresAt.setDate(expiresAt.getDate() + months * 30);

    // Activate premium subscription
    await supabase.from("subscriptions").insert({
      family_id: familyId,
      plan: "premium",
      payment_method: "paypal",
      transaction_id: transactionId,
      amount: capturedAmount,
      currency: currency,
      months: months,
      starts_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
    });

    console.log(
      `Premium activated for family ${familyId} - ${months} months via PayPal ${transactionId}`
    );

    return new Response(
      JSON.stringify({
        success: true,
        transaction_id: transactionId,
        expires_at: expiresAt.toISOString(),
        months: months,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("PayPal capture error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  }
});
