// M-Pesa Daraja API STK Push Edge Function
// Initiates a Lipa Na M-Pesa Online (STK Push) request
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MPESA_CONSUMER_KEY = Deno.env.get("MPESA_CONSUMER_KEY")!;
const MPESA_CONSUMER_SECRET = Deno.env.get("MPESA_CONSUMER_SECRET")!;
const MPESA_BUSINESS_SHORTCODE = Deno.env.get("MPESA_BUSINESS_SHORTCODE")!;
const MPESA_PASSKEY = Deno.env.get("MPESA_PASSKEY")!;
const MPESA_ENV = Deno.env.get("MPESA_ENV") || "sandbox"; // "sandbox" or "production"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const BASE_URL =
  MPESA_ENV === "production"
    ? "https://api.safaricom.co.ke"
    : "https://sandbox.safaricom.co.ke";

// Get OAuth access token from Daraja
async function getAccessToken(): Promise<string> {
  const credentials = btoa(`${MPESA_CONSUMER_KEY}:${MPESA_CONSUMER_SECRET}`);
  const response = await fetch(
    `${BASE_URL}/oauth/v1/generate?grant_type=client_credentials`,
    {
      headers: {
        Authorization: `Basic ${credentials}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to get access token: ${response.statusText}`);
  }

  const data = await response.json();
  return data.access_token;
}

// Generate timestamp in format YYYYMMDDHHmmss
function getTimestamp(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  const hours = String(now.getHours()).padStart(2, "0");
  const minutes = String(now.getMinutes()).padStart(2, "0");
  const seconds = String(now.getSeconds()).padStart(2, "0");
  return `${year}${month}${day}${hours}${minutes}${seconds}`;
}

// Generate password: Base64(BusinessShortCode + Passkey + Timestamp)
function generatePassword(timestamp: string): string {
  return btoa(`${MPESA_BUSINESS_SHORTCODE}${MPESA_PASSKEY}${timestamp}`);
}

// Format phone number to 254XXXXXXXXX format
function formatPhone(phone: string): string {
  let cleaned = phone.replace(/\s+/g, "").replace(/[^0-9]/g, "");
  if (cleaned.startsWith("0")) {
    cleaned = "254" + cleaned.substring(1);
  } else if (cleaned.startsWith("+254")) {
    cleaned = cleaned.substring(1);
  } else if (!cleaned.startsWith("254")) {
    cleaned = "254" + cleaned;
  }
  return cleaned;
}

Deno.serve(async (req) => {
  // CORS headers
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
    const { phone, amount, family_id, months } = await req.json();

    if (!phone || !amount || !family_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: phone, amount, family_id" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const formattedPhone = formatPhone(phone);
    const timestamp = getTimestamp();
    const password = generatePassword(timestamp);

    // Get Daraja access token
    const accessToken = await getAccessToken();

    // The callback URL is the mpesa-callback edge function
    const callbackUrl = `${SUPABASE_URL}/functions/v1/mpesa-callback`;

    // Initiate STK Push
    const stkResponse = await fetch(`${BASE_URL}/mpesa/stkpush/v1/processrequest`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        BusinessShortCode: MPESA_BUSINESS_SHORTCODE,
        Password: password,
        Timestamp: timestamp,
        TransactionType: "CustomerPayBillOnline",
        Amount: Math.ceil(amount),
        PartyA: formattedPhone,
        PartyB: MPESA_BUSINESS_SHORTCODE,
        PhoneNumber: formattedPhone,
        CallBackURL: callbackUrl,
        AccountReference: "TVParentalControl",
        TransactionDesc: `Premium ${months}mo subscription`,
      }),
    });

    const stkData = await stkResponse.json();

    if (stkData.ResponseCode !== "0") {
      return new Response(
        JSON.stringify({
          error: stkData.errorMessage || stkData.ResponseDescription || "STK push failed",
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

    // Store the pending transaction in Supabase for verification later
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    await supabase.from("mpesa_pending").insert({
      checkout_request_id: stkData.CheckoutRequestID,
      merchant_request_id: stkData.MerchantRequestID,
      family_id: family_id,
      phone: formattedPhone,
      amount: Math.ceil(amount),
      months: months,
      status: "pending",
    });

    return new Response(
      JSON.stringify({
        success: true,
        checkout_request_id: stkData.CheckoutRequestID,
        message: "STK push sent. Check your phone.",
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error) {
    console.error("M-Pesa STK Push error:", error);
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
