// M-Pesa Daraja API Callback Handler
// Safaricom sends payment confirmation/failure here after STK push
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  // This endpoint is called by Safaricom — no auth required
  try {
    const body = await req.json();
    console.log("M-Pesa callback received:", JSON.stringify(body));

    const { Body } = body;
    if (!Body?.stkCallback) {
      return new Response(JSON.stringify({ ResultCode: 0, ResultDesc: "Accepted" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const callback = Body.stkCallback;
    const checkoutRequestId = callback.CheckoutRequestID;
    const resultCode = callback.ResultCode;

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (resultCode !== 0) {
      // Payment failed or was cancelled
      await supabase
        .from("mpesa_pending")
        .update({
          status: "failed",
          result_code: resultCode,
          result_desc: callback.ResultDesc,
        })
        .eq("checkout_request_id", checkoutRequestId);

      return new Response(JSON.stringify({ ResultCode: 0, ResultDesc: "Accepted" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Payment successful — extract details from CallbackMetadata
    const metadata: Record<string, string | number> = {};
    if (callback.CallbackMetadata?.Item) {
      for (const item of callback.CallbackMetadata.Item) {
        metadata[item.Name] = item.Value;
      }
    }

    const mpesaReceiptNumber = metadata["MpesaReceiptNumber"] as string;
    const amount = metadata["Amount"] as number;
    const transactionDate = metadata["TransactionDate"] as string;

    // Update the pending transaction
    await supabase
      .from("mpesa_pending")
      .update({
        status: "completed",
        mpesa_receipt: mpesaReceiptNumber,
        result_code: resultCode,
        result_desc: callback.ResultDesc,
        paid_amount: amount,
        transaction_date: transactionDate?.toString(),
      })
      .eq("checkout_request_id", checkoutRequestId);

    // Look up the pending transaction to get family_id and months
    const { data: pendingTx } = await supabase
      .from("mpesa_pending")
      .select("family_id, months, amount")
      .eq("checkout_request_id", checkoutRequestId)
      .single();

    if (pendingTx) {
      // Activate the premium subscription
      const now = new Date();
      const months = pendingTx.months || 1;

      // Check if there's an existing active subscription to extend
      const { data: existingSub } = await supabase
        .from("subscriptions")
        .select("expires_at")
        .eq("family_id", pendingTx.family_id)
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

      await supabase.from("subscriptions").insert({
        family_id: pendingTx.family_id,
        plan: "premium",
        payment_method: "mpesa",
        transaction_id: mpesaReceiptNumber,
        amount: amount || pendingTx.amount,
        currency: "KES",
        months: months,
        starts_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
      });

      console.log(
        `Premium activated for family ${pendingTx.family_id} via M-Pesa ${mpesaReceiptNumber}`
      );
    }

    return new Response(JSON.stringify({ ResultCode: 0, ResultDesc: "Accepted" }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("M-Pesa callback error:", error);
    // Always return success to Safaricom to prevent retries
    return new Response(JSON.stringify({ ResultCode: 0, ResultDesc: "Accepted" }), {
      headers: { "Content-Type": "application/json" },
    });
  }
});
