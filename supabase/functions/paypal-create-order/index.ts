// PayPal REST API — Create Order
// Creates a PayPal order and returns the approval URL for the user
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const PAYPAL_CLIENT_ID = Deno.env.get("PAYPAL_CLIENT_ID")!;
const PAYPAL_CLIENT_SECRET = Deno.env.get("PAYPAL_CLIENT_SECRET")!;
const PAYPAL_ENV = Deno.env.get("PAYPAL_ENV") || "sandbox"; // "sandbox" or "live"
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const BASE_URL =
  PAYPAL_ENV === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";

// Get PayPal OAuth access token
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
    const { amount, currency, months, family_id } = await req.json();

    if (!amount || !family_id || !months) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: amount, family_id, months" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const accessToken = await getAccessToken();

    // Create PayPal order
    const orderResponse = await fetch(`${BASE_URL}/v2/checkout/orders`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        intent: "CAPTURE",
        purchase_units: [
          {
            reference_id: family_id,
            description: `TV Parental Control Premium - ${months} month${months > 1 ? "s" : ""}`,
            amount: {
              currency_code: currency || "USD",
              value: amount.toFixed(2),
            },
            custom_id: JSON.stringify({ family_id, months }),
          },
        ],
        application_context: {
          brand_name: "TV Parental Control",
          landing_page: "NO_PREFERENCE",
          user_action: "PAY_NOW",
          // Deep link back to the app after PayPal approval
          return_url: "tvparentalcontrol://paypal/success",
          cancel_url: "tvparentalcontrol://paypal/cancel",
        },
      }),
    });

    if (!orderResponse.ok) {
      const errorData = await orderResponse.json();
      console.error("PayPal create order error:", errorData);
      return new Response(
        JSON.stringify({ error: "Failed to create PayPal order" }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    const order = await orderResponse.json();

    // Find the approval URL
    const approvalUrl = order.links?.find(
      (link: { rel: string }) => link.rel === "approve"
    )?.href;

    // Store pending PayPal order in Supabase
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    await supabase.from("paypal_pending").insert({
      order_id: order.id,
      family_id: family_id,
      amount: amount,
      currency: currency || "USD",
      months: months,
      status: "created",
    });

    return new Response(
      JSON.stringify({
        success: true,
        order_id: order.id,
        approval_url: approvalUrl,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("PayPal create order error:", error);
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
