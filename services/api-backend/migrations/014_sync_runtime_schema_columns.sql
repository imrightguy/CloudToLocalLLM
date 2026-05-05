-- Migration 014: Sync tables with runtime Drizzle schema fields used by controllers

ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS qualification_state TEXT NOT NULL DEFAULT 'unknown';

ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS qualification_reason_code TEXT;

ALTER TABLE leads
  ADD COLUMN IF NOT EXISTS qualification_reason_note TEXT;

CREATE INDEX IF NOT EXISTS leads_source_idx ON leads(source);
CREATE INDEX IF NOT EXISTS leads_assigned_employee_id_idx ON leads(assigned_employee_id);
CREATE INDEX IF NOT EXISTS leads_building_id_idx ON leads(building_id);
CREATE INDEX IF NOT EXISTS leads_stage_idx ON leads(stage);

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS tenant_confirmation_requested_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS tenant_confirmed_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS tenant_declined_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS occupant_notified BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS employee_confirmation_requested_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS employee_confirmed_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS employee_declined_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS morning_reminder_sent_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS reminder_24h_queued_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS reminder_2h_queued_at TIMESTAMP;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS source_thread_id UUID;

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS coordination_state TEXT NOT NULL DEFAULT 'message_only';
