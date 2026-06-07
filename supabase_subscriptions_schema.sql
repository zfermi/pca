-- Subscriptions table for freemium gating
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  family_id UUID REFERENCES families(id) ON DELETE CASCADE NOT NULL,
  plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
  payment_method TEXT CHECK (payment_method IN ('paypal', 'mpesa')),
  transaction_id TEXT,
  amount NUMERIC(10, 2),
  currency TEXT DEFAULT 'USD',
  months INTEGER DEFAULT 1,
  starts_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick family lookup
CREATE INDEX idx_subscriptions_family ON subscriptions(family_id);

-- Index for finding active subscriptions
CREATE INDEX idx_subscriptions_active ON subscriptions(family_id, expires_at DESC);

-- RLS policies
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read their family's subscriptions
CREATE POLICY sub_select ON subscriptions
  FOR SELECT TO authenticated
  USING (
    family_id IN (
      SELECT family_id FROM devices WHERE user_id = auth.uid()
    )
    OR
    family_id IN (
      SELECT id FROM families WHERE owner_id = auth.uid()
    )
  );

-- Allow authenticated users to insert subscriptions for their family
CREATE POLICY sub_insert ON subscriptions
  FOR INSERT TO authenticated
  WITH CHECK (
    family_id IN (
      SELECT family_id FROM devices WHERE user_id = auth.uid()
    )
    OR
    family_id IN (
      SELECT id FROM families WHERE owner_id = auth.uid()
    )
  );
