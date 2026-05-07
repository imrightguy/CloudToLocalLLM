-- Migration 020: add company-scoped property photo records

CREATE TABLE IF NOT EXISTS property_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL,
  building_id UUID NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
  unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
  room_context TEXT,
  use_case TEXT NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  document_ref_id TEXT,
  file_name TEXT NOT NULL,
  stored_file_name TEXT NOT NULL,
  storage_provider TEXT NOT NULL DEFAULT 'external_url',
  storage_key TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  file_size_bytes INTEGER,
  mime_type TEXT,
  url TEXT NOT NULL,
  captured_at TIMESTAMP,
  uploaded_at TIMESTAMP NOT NULL DEFAULT NOW(),
  metadata JSONB NOT NULL DEFAULT '{}',
  uploaded_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS property_photos_company_id_idx ON property_photos(company_id);
CREATE INDEX IF NOT EXISTS property_photos_company_building_id_idx ON property_photos(company_id, building_id);
CREATE INDEX IF NOT EXISTS property_photos_company_unit_id_idx ON property_photos(company_id, unit_id);
CREATE INDEX IF NOT EXISTS property_photos_company_use_case_idx ON property_photos(company_id, use_case);
