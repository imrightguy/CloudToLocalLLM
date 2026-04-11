-- Add confirmation token to visits table
-- Enables web-based tenant confirmation via clickable SMS link

ALTER TABLE visits ADD COLUMN IF NOT EXISTS confirmation_token TEXT UNIQUE;
CREATE INDEX IF NOT EXISTS idx_visits_confirmation_token ON visits(confirmation_token) WHERE confirmation_token IS NOT NULL;
