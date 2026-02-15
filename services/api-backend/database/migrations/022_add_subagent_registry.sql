-- Migration: Add Subagent Registry Table
-- Created: 2026-02-15
-- Description: Creates the subagent_registry table for managing subagent lifecycle and status tracking

-- Subagent Registry Table
-- Tracks subagent instances spawned by main agents
CREATE TABLE IF NOT EXISTS subagent_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subagent_id VARCHAR(100) UNIQUE NOT NULL,
  agent_id VARCHAR(100) NOT NULL,
  label VARCHAR(100),
  task TEXT,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  created_at TIMESTAMP DEFAULT NOW(),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  result_json JSONB,
  logs TEXT,
  error_message TEXT
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_subagent_registry_subagent_id ON subagent_registry(subagent_id);
CREATE INDEX IF NOT EXISTS idx_subagent_registry_agent_id ON subagent_registry(agent_id);
CREATE INDEX IF NOT EXISTS idx_subagent_registry_status ON subagent_registry(status);
CREATE INDEX IF NOT EXISTS idx_subagent_registry_created_at ON subagent_registry(created_at DESC);

-- Create trigger for automatic updated_at if needed
-- Note: This table doesn't have an updated_at column, but if added later:
-- DO $$
-- BEGIN
--     IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_subagent_registry_updated_at') THEN
--         CREATE TRIGGER update_subagent_registry_updated_at BEFORE UPDATE ON subagent_registry
--             FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
--     END IF;
-- END $$;

-- Add comments for documentation
COMMENT ON TABLE subagent_registry IS 'Registry for tracking subagent lifecycle and execution status';
COMMENT ON COLUMN subagent_registry.subagent_id IS 'Unique identifier for the subagent instance';
COMMENT ON COLUMN subagent_registry.agent_id IS 'Parent agent that spawned this subagent';
COMMENT ON COLUMN subagent_registry.label IS 'Human-readable label for the subagent';
COMMENT ON COLUMN subagent_registry.task IS 'Task description or prompt given to the subagent';
COMMENT ON COLUMN subagent_registry.status IS 'Current status: pending, running, completed, failed';
COMMENT ON COLUMN subagent_registry.result_json IS 'Execution result stored as JSON';
COMMENT ON COLUMN subagent_registry.logs IS 'Execution logs or debug output';
COMMENT ON COLUMN subagent_registry.error_message IS 'Error message if status is failed';
