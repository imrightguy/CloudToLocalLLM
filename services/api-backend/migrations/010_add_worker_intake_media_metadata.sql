-- Migration 010: Add media metadata to worker intake records

ALTER TABLE worker_intake_records
  ADD COLUMN IF NOT EXISTS twilio_message_sid TEXT;

ALTER TABLE worker_intake_records
  ADD COLUMN IF NOT EXISTS media_urls JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE worker_intake_records
  ADD COLUMN IF NOT EXISTS media_content_types JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS worker_intake_records_twilio_message_sid_unique
  ON worker_intake_records(twilio_message_sid);
