-- Migration 013: Require explicit verification evidence for renovation task completion

ALTER TABLE renovation_tasks
  ADD COLUMN IF NOT EXISTS verification_evidence JSONB NOT NULL DEFAULT '[]'::jsonb;
