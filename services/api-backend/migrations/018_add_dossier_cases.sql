-- Migration 018: add TAL dossier cases and case items

CREATE TABLE IF NOT EXISTS dossier_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL,
  lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
  unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
  building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
  problem_category TEXT NOT NULL,
  incident_window_start TIMESTAMP,
  incident_window_end TIMESTAMP,
  status TEXT NOT NULL DEFAULT 'draft',
  factual_summary TEXT NOT NULL DEFAULT '',
  next_steps JSONB NOT NULL DEFAULT '[]',
  review_notes TEXT,
  reviewed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMP,
  exported_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  exported_at TIMESTAMP,
  created_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS dossier_cases_company_id_idx ON dossier_cases(company_id);
CREATE INDEX IF NOT EXISTS dossier_cases_company_status_idx ON dossier_cases(company_id, status);
CREATE INDEX IF NOT EXISTS dossier_cases_company_unit_idx ON dossier_cases(company_id, unit_id);

CREATE TABLE IF NOT EXISTS dossier_case_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL,
  dossier_case_id UUID NOT NULL REFERENCES dossier_cases(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL,
  source_record_id TEXT NOT NULL,
  source_at TIMESTAMP,
  sort_order INTEGER NOT NULL DEFAULT 0,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  supporting_label TEXT,
  details JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS dossier_case_items_dossier_case_id_idx ON dossier_case_items(dossier_case_id);
CREATE INDEX IF NOT EXISTS dossier_case_items_company_id_idx ON dossier_case_items(company_id);
CREATE INDEX IF NOT EXISTS dossier_case_items_source_type_idx ON dossier_case_items(source_type);
