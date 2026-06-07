-- FCM Tokens table: stores device FCM tokens for push notifications
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'android',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(device_id)
);

-- Notification queue: TV devices insert rows, Edge Function processes them
CREATE TABLE IF NOT EXISTS notification_queue (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  source_device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  child_name TEXT NOT NULL,
  details TEXT,
  processed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS policies for fcm_tokens
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own device tokens"
  ON fcm_tokens FOR ALL
  USING (
    family_id IN (
      SELECT id FROM families WHERE owner_id = auth.uid()
    )
    OR
    device_id IN (
      SELECT id FROM devices WHERE user_id = auth.uid()
    )
  );

-- RLS policies for notification_queue
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert notifications for their family"
  ON notification_queue FOR INSERT
  WITH CHECK (
    family_id IN (
      SELECT id FROM families WHERE owner_id = auth.uid()
    )
    OR
    source_device_id IN (
      SELECT id FROM devices WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can read their family notifications"
  ON notification_queue FOR SELECT
  USING (
    family_id IN (
      SELECT id FROM families WHERE owner_id = auth.uid()
    )
    OR
    source_device_id IN (
      SELECT id FROM devices WHERE user_id = auth.uid()
    )
  );

-- Index for faster notification processing
CREATE INDEX IF NOT EXISTS idx_notification_queue_unprocessed
  ON notification_queue (family_id, processed)
  WHERE processed = FALSE;

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_family
  ON fcm_tokens (family_id);

-- Enable realtime on notification_queue so Edge Functions can listen
ALTER PUBLICATION supabase_realtime ADD TABLE notification_queue;

-- Database webhook/trigger: when a notification is inserted,
-- call the Edge Function to send FCM push.
-- This uses pg_net to call the Edge Function directly.

CREATE OR REPLACE FUNCTION notify_parents()
RETURNS TRIGGER AS $$
DECLARE
  token_record RECORD;
  notification_title TEXT;
  notification_body TEXT;
  fcm_payload JSONB;
  supabase_url TEXT;
  service_role_key TEXT;
BEGIN
  -- Build notification content based on type
  CASE NEW.type
    WHEN 'session_started' THEN
      notification_title := '▶️ Session Started';
      notification_body := NEW.details;
    WHEN 'session_ended' THEN
      notification_title := '⏹️ Session Ended';
      notification_body := NEW.details;
    WHEN 'time_limit_reached' THEN
      notification_title := '⏰ Time Limit Reached';
      notification_body := NEW.details;
    WHEN 'blocked_app' THEN
      notification_title := '🚫 Blocked App Alert';
      notification_body := NEW.details;
    ELSE
      notification_title := 'Parental Control Alert';
      notification_body := NEW.details;
  END CASE;

  -- Get all FCM tokens for this family (excluding the source device)
  FOR token_record IN
    SELECT token FROM fcm_tokens
    WHERE family_id = NEW.family_id
    AND device_id != NEW.source_device_id
  LOOP
    -- Use pg_net to send FCM via Google's HTTP v1 API through Edge Function
    PERFORM net.http_post(
      url := 'https://cbvzkbhkoxqzakuslwjn.supabase.co/functions/v1/send-fcm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      ),
      body := jsonb_build_object(
        'token', token_record.token,
        'title', notification_title,
        'body', notification_body,
        'data', jsonb_build_object(
          'type', NEW.type,
          'child_name', NEW.child_name,
          'family_id', NEW.family_id::text
        )
      )
    );
  END LOOP;

  -- Mark as processed
  NEW.processed := TRUE;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: The trigger approach using pg_net requires the pg_net extension.
-- Alternative: Use a Supabase Edge Function with a database webhook.
-- For simplicity, we'll use the notification_queue table and process
-- notifications from the client side or via Edge Function cron.

-- Simple approach: Phone app polls for unprocessed notifications
-- and shows them as local notifications using flutter_local_notifications.
