-- Migration 016: add missing runtime columns used by lead/visit controllers

ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS qualification_state TEXT NOT NULL DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS qualification_reason_code TEXT,
  ADD COLUMN IF NOT EXISTS qualification_reason_note TEXT;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS tenant_confirmation_requested_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS tenant_confirmed_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS tenant_declined_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS employee_confirmation_requested_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS employee_confirmed_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS employee_declined_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS morning_reminder_sent_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS reminder_24h_queued_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS reminder_2h_queued_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS source_thread_id UUID,
  ADD COLUMN IF NOT EXISTS coordination_state TEXT NOT NULL DEFAULT 'message_only';
