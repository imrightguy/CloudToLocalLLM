-- Migration 011: Add visit lifecycle metadata

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS failure_reason_code TEXT;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS no_show_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS rescheduled_at TIMESTAMP;
