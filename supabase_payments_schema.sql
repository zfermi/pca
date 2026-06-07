-- Pending M-Pesa transactions (tracks STK push requests)
CREATE TABLE IF NOT EXISTS mpesa_pending (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  checkout_request_id TEXT UNIQUE,
  merchant_request_id TEXT,
  family_id UUID REFERENCES families(id) ON DELETE CASCADE NOT NULL,
  phone TEXT NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  months INTEGER DEFAULT 1,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  mpesa_receipt TEXT,
  result_code INTEGER,
  result_desc TEXT,
  paid_amount NUMERIC(10, 2),
  transaction_date TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pending PayPal orders (tracks order creation → capture)
CREATE TABLE IF NOT EXISTS paypal_pending (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id TEXT UNIQUE,
  family_id UUID REFERENCES families(id) ON DELETE CASCADE NOT NULL,
  amount NUMERIC(10, 2) NOT NULL,
  currency TEXT DEFAULT 'USD',
  months INTEGER DEFAULT 1,
  status TEXT DEFAULT 'created' CHECK (status IN ('created', 'approved', 'completed', 'failed')),
  transaction_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_mpesa_pending_family ON mpesa_pending(family_id);
CREATE INDEX idx_mpesa_pending_checkout ON mpesa_pending(checkout_request_id);
CREATE INDEX idx_paypal_pending_family ON paypal_pending(family_id);
CREATE INDEX idx_paypal_pending_order ON paypal_pending(order_id);

-- RLS — these tables are accessed by edge functions with service_role key,
-- but we add policies for safety
ALTER TABLE mpesa_pending ENABLE ROW LEVEL SECURITY;
ALTER TABLE paypal_pending ENABLE ROW LEVEL SECURITY;

-- Edge functions use service_role key (bypasses RLS),
-- but allow authenticated users to check their own payment status
CREATE POLICY mpesa_select ON mpesa_pending
  FOR SELECT TO authenticated
  USING (
    family_id IN (
      SELECT family_id FROM devices WHERE user_id = auth.uid()
    )
    OR family_id IN (
      SELECT id FROM families WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY paypal_select ON paypal_pending
  FOR SELECT TO authenticated
  USING (
    family_id IN (
      SELECT family_id FROM devices WHERE user_id = auth.uid()
    )
    OR family_id IN (
      SELECT id FROM families WHERE owner_id = auth.uid()
    )
  );
