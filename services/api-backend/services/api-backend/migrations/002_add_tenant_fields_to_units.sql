-- Add tenant fields to units table
-- Tracks current occupant info and lease end date for visit notifications

ALTER TABLE units ADD COLUMN IF NOT EXISTS tenant_name TEXT;
ALTER TABLE units ADD COLUMN IF NOT EXISTS tenant_phone TEXT;
ALTER TABLE units ADD COLUMN IF NOT EXISTS tenant_lease_end TIMESTAMP;

-- Add occupant notification tracking to visits
ALTER TABLE visits ADD COLUMN IF NOT EXISTS occupant_notified BOOLEAN NOT NULL DEFAULT false;
