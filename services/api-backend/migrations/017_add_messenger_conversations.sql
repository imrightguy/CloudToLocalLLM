-- Migration 017: persist Messenger conversation state for restart-safe workflows

CREATE TABLE IF NOT EXISTS messenger_conversations (
  sender_id TEXT PRIMARY KEY,
  state TEXT NOT NULL DEFAULT 'NEW',
  lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
  language TEXT NOT NULL DEFAULT 'fr',
  first_name TEXT,
  last_name TEXT,
  selected_building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
  selected_unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
  last_activity_at TIMESTAMP NOT NULL DEFAULT NOW(),
  conversation_data JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS messenger_conversations_lead_id_idx ON messenger_conversations(lead_id);
CREATE INDEX IF NOT EXISTS messenger_conversations_last_activity_at_idx ON messenger_conversations(last_activity_at);
