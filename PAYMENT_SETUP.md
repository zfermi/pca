# Payment Integration Setup Guide

## Architecture

```
Flutter App
  ├── M-Pesa: Phone number → Edge Function → Daraja STK Push → User's phone
  │   └── Safaricom callback → Edge Function → activates subscription in Supabase
  │
  └── PayPal: Edge Function → Creates order → Opens PayPal in browser → User approves
      └── App captures order → Edge Function → activates subscription in Supabase
```

## 1. M-Pesa (Safaricom Daraja API)

### Get Credentials
1. Go to [developer.safaricom.co.ke](https://developer.safaricom.co.ke)
2. Create an account and a new app
3. Get your **Consumer Key** and **Consumer Secret**
4. For testing, use the **Sandbox** environment
5. For production, apply for a **Paybill** or **Till Number**

### Sandbox Test Credentials (from Safaricom)
- Business Shortcode: `174379`
- Passkey: `bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919`
- Test phone: `254708374149`

### Set Edge Function Secrets
```bash
# Navigate to project directory
cd C:\Users\Administrator\Desktop\TVPCA

# Link to your Supabase project (one-time)
supabase link --project-ref cbvzkbhkoxqzakuslwjn

# Set M-Pesa secrets
supabase secrets set MPESA_CONSUMER_KEY=your_consumer_key_here
supabase secrets set MPESA_CONSUMER_SECRET=your_consumer_secret_here
supabase secrets set MPESA_BUSINESS_SHORTCODE=174379
supabase secrets set MPESA_PASSKEY=bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919
supabase secrets set MPESA_ENV=sandbox
```

For production:
```bash
supabase secrets set MPESA_BUSINESS_SHORTCODE=your_paybill_number
supabase secrets set MPESA_PASSKEY=your_production_passkey
supabase secrets set MPESA_ENV=production
```

## 2. PayPal

### Get Credentials
1. Go to [developer.paypal.com](https://developer.paypal.com)
2. Create a **REST API app** under Dashboard → Apps & Credentials
3. Get your **Client ID** and **Client Secret**
4. For testing, use the **Sandbox** tab
5. For production, switch to **Live** tab

### Set Edge Function Secrets
```bash
supabase secrets set PAYPAL_CLIENT_ID=your_paypal_client_id
supabase secrets set PAYPAL_CLIENT_SECRET=your_paypal_client_secret
supabase secrets set PAYPAL_ENV=sandbox
```

For production:
```bash
supabase secrets set PAYPAL_ENV=live
```

## 3. Deploy Edge Functions

```bash
# Deploy all functions
supabase functions deploy mpesa-stk-push --no-verify-jwt
supabase functions deploy mpesa-callback --no-verify-jwt
supabase functions deploy paypal-create-order --no-verify-jwt
supabase functions deploy paypal-capture-order --no-verify-jwt
```

Note: `--no-verify-jwt` is needed because:
- `mpesa-callback` is called by Safaricom (no JWT)
- The other functions receive JWT from the Flutter app's Supabase auth

## 4. Deep Link Setup (PayPal return)

Add to `android/app/src/main/AndroidManifest.xml` inside the `<activity>` tag:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="tvparentalcontrol" android:host="paypal" />
</intent-filter>
```

## 5. Testing

### Test M-Pesa (Sandbox)
1. Use Safaricom sandbox test phone number: `254708374149`
2. The STK push won't actually appear on a real phone in sandbox
3. Use the Daraja API simulator to trigger callbacks

### Test PayPal (Sandbox)
1. Create sandbox buyer/seller accounts at developer.paypal.com
2. Use sandbox buyer email/password when PayPal checkout opens
3. Payment will be captured in sandbox mode

## Supabase Tables Created

| Table | Purpose |
|-------|---------|
| `subscriptions` | Active/expired premium subscriptions |
| `mpesa_pending` | Tracks M-Pesa STK push requests and callbacks |
| `paypal_pending` | Tracks PayPal order creation and capture |

## Payment Flow

### M-Pesa Flow
1. User enters phone number in app
2. App calls `mpesa-stk-push` edge function
3. Edge function gets Daraja OAuth token, sends STK push
4. User sees M-Pesa prompt on phone, enters PIN
5. Safaricom sends callback to `mpesa-callback` edge function
6. Callback verifies payment, inserts into `subscriptions` table
7. App polls `mpesa_pending` table for status, refreshes subscription

### PayPal Flow
1. User clicks "Pay with PayPal" in app
2. App calls `paypal-create-order` edge function
3. Edge function creates PayPal order, returns approval URL
4. App opens PayPal in browser, user approves payment
5. User returns to app (via deep link or manually)
6. App calls `paypal-capture-order` edge function
7. Edge function captures payment, inserts into `subscriptions` table
8. App refreshes subscription state
