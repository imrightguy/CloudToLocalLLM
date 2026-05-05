-- Migration 015: Add communication_threads table used by visit coordination flows

CREATE TABLE IF NOT EXISTS communication_threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL UNIQUE REFERENCES leads(id) ON DELETE CASCADE,
  latest_visit_id UUID REFERENCES visits(id) ON DELETE SET NULL,
  booking_state TEXT NOT NULL DEFAULT 'unbooked',
  booking_reason_code TEXT,
  booking_state_updated_at TIMESTAMP,
  coordination_state TEXT NOT NULL DEFAULT 'message_only',
  message_count INTEGER NOT NULL DEFAULT 0,
  last_message_at TIMESTAMP,
  last_message_type TEXT,
  last_message_direction TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS comm_threads_lead_id_idx ON communication_threads(lead_id);
CREATE INDEX IF NOT EXISTS comm_threads_coordination_state_idx ON communication_threads(coordination_state);
CREATE INDEX IF NOT EXISTS comm_threads_booking_state_idx ON communication_threads(booking_state);
