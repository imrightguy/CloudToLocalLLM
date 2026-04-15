-- Migration 007: Add renewal offers table

CREATE TABLE IF NOT EXISTS renewal_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lease_id UUID NOT NULL REFERENCES leases(id) ON DELETE CASCADE,
  new_start_date DATE NOT NULL,
  new_end_date DATE NOT NULL,
  new_rent_cents INTEGER NOT NULL,
  new_deposit_cents INTEGER NOT NULL DEFAULT 0,
  terms JSONB DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending',
  sent_at TIMESTAMP,
  sent_via TEXT,
  tenant_response TEXT,
  responded_at TIMESTAMP,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_renewal_offers_lease_id ON renewal_offers(lease_id);
CREATE INDEX IF NOT EXISTS idx_renewal_offers_status ON renewal_offers(status);
CREATE INDEX IF NOT EXISTS idx_renewal_offers_lease_status ON renewal_offers(lease_id, status);
