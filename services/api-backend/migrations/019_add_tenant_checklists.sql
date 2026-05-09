-- Migration 019: add tenant checklist sessions, steps, evidence, signatures, and audit events

CREATE TABLE IF NOT EXISTS tenant_checklist_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  lease_id UUID REFERENCES leases(id) ON DELETE SET NULL,
  checklist_type TEXT NOT NULL DEFAULT 'move_in',
  state TEXT NOT NULL DEFAULT 'draft',
  current_step_key TEXT,
  current_step_order INTEGER NOT NULL DEFAULT 0,
  tenant_name TEXT,
  tenant_phone TEXT,
  started_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  resumed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  paused_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  completed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  submitted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  started_at TIMESTAMP,
  resumed_at TIMESTAMP,
  paused_at TIMESTAMP,
  paused_reason TEXT,
  submitted_at TIMESTAMP,
  completed_at TIMESTAMP,
  reviewed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMP,
  confirmation_note TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS tenant_checklist_sessions_unit_id_idx ON tenant_checklist_sessions(unit_id);
CREATE INDEX IF NOT EXISTS tenant_checklist_sessions_lease_id_idx ON tenant_checklist_sessions(lease_id);
CREATE INDEX IF NOT EXISTS tenant_checklist_sessions_state_idx ON tenant_checklist_sessions(state);
CREATE INDEX IF NOT EXISTS tenant_checklist_sessions_checklist_type_idx ON tenant_checklist_sessions(checklist_type);

CREATE TABLE IF NOT EXISTS tenant_checklist_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES tenant_checklist_sessions(id) ON DELETE CASCADE,
  step_key TEXT NOT NULL,
  step_order INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  required_fields JSONB NOT NULL DEFAULT '[]',
  notes TEXT,
  blocked_reason TEXT,
  completed_at TIMESTAMP,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS tenant_checklist_steps_session_step_key_unique ON tenant_checklist_steps(session_id, step_key);
CREATE INDEX IF NOT EXISTS tenant_checklist_steps_session_id_idx ON tenant_checklist_steps(session_id);
CREATE INDEX IF NOT EXISTS tenant_checklist_steps_session_order_idx ON tenant_checklist_steps(session_id, step_order);
CREATE INDEX IF NOT EXISTS tenant_checklist_steps_status_idx ON tenant_checklist_steps(status);

CREATE TABLE IF NOT EXISTS tenant_checklist_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES tenant_checklist_sessions(id) ON DELETE CASCADE,
  step_id UUID NOT NULL REFERENCES tenant_checklist_steps(id) ON DELETE CASCADE,
  document_ref_id TEXT,
  file_name TEXT,
  mime_type TEXT,
  url TEXT,
  caption TEXT,
  taken_at TIMESTAMP,
  uploaded_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS tenant_checklist_attachments_session_id_idx ON tenant_checklist_attachments(session_id);
CREATE INDEX IF NOT EXISTS tenant_checklist_attachments_step_id_idx ON tenant_checklist_attachments(step_id);

CREATE TABLE IF NOT EXISTS tenant_checklist_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES tenant_checklist_sessions(id) ON DELETE CASCADE,
  signature_type TEXT NOT NULL,
  signer_name TEXT,
  signer_role TEXT,
  method TEXT NOT NULL DEFAULT 'typed',
  status TEXT NOT NULL DEFAULT 'captured',
  signature_data JSONB NOT NULL DEFAULT '{}',
  signed_at TIMESTAMP NOT NULL DEFAULT NOW(),
  signed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS tenant_checklist_signatures_session_type_unique ON tenant_checklist_signatures(session_id, signature_type);
CREATE INDEX IF NOT EXISTS tenant_checklist_signatures_session_id_idx ON tenant_checklist_signatures(session_id);

CREATE TABLE IF NOT EXISTS tenant_checklist_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES tenant_checklist_sessions(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  actor_type TEXT NOT NULL DEFAULT 'user',
  actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  from_state TEXT,
  to_state TEXT,
  step_id UUID REFERENCES tenant_checklist_steps(id) ON DELETE SET NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS tenant_checklist_events_session_id_idx ON tenant_checklist_events(session_id);
CREATE INDEX IF NOT EXISTS tenant_checklist_events_session_event_type_idx ON tenant_checklist_events(session_id, event_type);
CREATE INDEX IF NOT EXISTS tenant_checklist_events_created_at_idx ON tenant_checklist_events(created_at);
