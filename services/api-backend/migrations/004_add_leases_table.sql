-- ─── 004: Lease Agreements ───
-- Formal lease lifecycle management replacing simple tenant fields on units.

CREATE TABLE IF NOT EXISTS leases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,

  tenant_first_name TEXT NOT NULL,
  tenant_last_name TEXT NOT NULL,
  tenant_email TEXT,
  tenant_phone TEXT,

  rent_cents INTEGER NOT NULL,
  deposit_cents INTEGER NOT NULL DEFAULT 0,

  start_date DATE NOT NULL,
  end_date DATE NOT NULL,

  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'expired', 'terminated', 'renewed')),

  terms JSONB DEFAULT '{}',

  signed_at TIMESTAMPTZ,

  created_by UUID REFERENCES users(id) ON DELETE SET NULL,

  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leases_unit_id ON leases(unit_id);
CREATE INDEX IF NOT EXISTS idx_leases_lead_id ON leases(lead_id) WHERE lead_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_leases_status ON leases(status);
CREATE INDEX IF NOT EXISTS idx_leases_dates ON leases(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_leases_created_by ON leases(created_by) WHERE created_by IS NOT NULL;
