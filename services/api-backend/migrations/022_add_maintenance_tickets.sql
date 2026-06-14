-- Migration 022: Add Maintenance Tickets (Voice AI / Vapi pillar)

CREATE TABLE IF NOT EXISTS maintenance_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  urgency TEXT NOT NULL DEFAULT 'moyenne',
  status TEXT NOT NULL DEFAULT 'ouvert',
  source TEXT NOT NULL DEFAULT 'manual',
  tenant_id UUID,
  tenant_name TEXT,
  caller_phone TEXT,
  unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
  building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
  photos JSONB NOT NULL DEFAULT '[]',
  vapi_call_id TEXT,
  resolved_at TIMESTAMP,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS maintenance_tickets_status_idx ON maintenance_tickets(status);
CREATE INDEX IF NOT EXISTS maintenance_tickets_urgency_idx ON maintenance_tickets(urgency);
CREATE INDEX IF NOT EXISTS maintenance_tickets_building_id_idx ON maintenance_tickets(building_id);
CREATE INDEX IF NOT EXISTS maintenance_tickets_unit_id_idx ON maintenance_tickets(unit_id);
CREATE UNIQUE INDEX IF NOT EXISTS maintenance_tickets_vapi_call_id_unique ON maintenance_tickets(vapi_call_id) WHERE vapi_call_id IS NOT NULL;
