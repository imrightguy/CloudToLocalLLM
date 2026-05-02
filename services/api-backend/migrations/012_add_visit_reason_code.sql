-- Migration 012: Add canonical visit reason code column

ALTER TABLE visits
  ADD COLUMN IF NOT EXISTS reason_code TEXT;

UPDATE visits
SET reason_code = COALESCE(reason_code, failure_reason_code)
WHERE reason_code IS NULL
  AND failure_reason_code IS NOT NULL;
