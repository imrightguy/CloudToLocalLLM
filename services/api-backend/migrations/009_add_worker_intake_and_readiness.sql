-- Migration 009: Add worker intake records and unit readiness projection

CREATE TABLE IF NOT EXISTS worker_intake_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  renovation_record_id UUID NOT NULL REFERENCES renovations(id) ON DELETE CASCADE,
  task_id UUID REFERENCES renovation_tasks(id) ON DELETE SET NULL,
  order_id UUID REFERENCES renovation_orders(id) ON DELETE SET NULL,
  source_phone TEXT NOT NULL,
  worker_name TEXT,
  message_body TEXT NOT NULL,
  message_kind TEXT NOT NULL DEFAULT 'update',
  status TEXT NOT NULL DEFAULT 'new',
  confidence NUMERIC(5, 4),
  summary TEXT,
  raw_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  photo_count INTEGER NOT NULL DEFAULT 0,
  received_at TIMESTAMP NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMP,
  resolved_at TIMESTAMP,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS worker_intake_records_renovation_record_id_idx ON worker_intake_records(renovation_record_id);
CREATE INDEX IF NOT EXISTS worker_intake_records_task_id_idx ON worker_intake_records(task_id);
CREATE INDEX IF NOT EXISTS worker_intake_records_status_idx ON worker_intake_records(status);
CREATE INDEX IF NOT EXISTS worker_intake_records_message_kind_idx ON worker_intake_records(message_kind);

CREATE TABLE IF NOT EXISTS unit_readiness (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  current_renovation_record_id UUID REFERENCES renovations(id) ON DELETE SET NULL,
  ops_status TEXT NOT NULL DEFAULT 'not_started',
  leasing_status TEXT NOT NULL DEFAULT 'not_ready',
  blocking_count INTEGER NOT NULL DEFAULT 0,
  blocking_summary TEXT,
  ready_at TIMESTAMP,
  handed_off_at TIMESTAMP,
  leased_at TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS unit_readiness_unit_id_unique ON unit_readiness(unit_id);
CREATE INDEX IF NOT EXISTS unit_readiness_ops_status_idx ON unit_readiness(ops_status);
CREATE INDEX IF NOT EXISTS unit_readiness_leasing_status_idx ON unit_readiness(leasing_status);
