-- init.sql - Database schema for CloudToLocalLLM

-- Rate limit tracking table
CREATE TABLE IF NOT EXISTS model_capacity (
    model_id VARCHAR(50) PRIMARY KEY,
    provider VARCHAR(20) NOT NULL,
    display_name VARCHAR(100),
    concurrent_used INTEGER DEFAULT 0,
    concurrent_limit INTEGER NOT NULL,
    tpm_used INTEGER DEFAULT 0,
    tpm_limit INTEGER,
    rpm_used INTEGER DEFAULT 0,
    rpm_limit INTEGER,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' -- active, degraded, offline
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_model_capacity_provider ON model_capacity(provider);
CREATE INDEX IF NOT EXISTS idx_model_capacity_status ON model_capacity(status);

-- Insert known GLM rate limits
INSERT INTO model_capacity (model_id, provider, display_name, concurrent_limit, tpm_limit, rpm_limit) VALUES
    ('glm-4-plus', 'zhipu', 'GLM-4 Plus', 20, NULL, NULL),
    ('glm-4-32b-0414-128k', 'zhipu', 'GLM-4 32B', 15, NULL, NULL),
    ('glm-4.5', 'zhipu', 'GLM-4.5', 10, NULL, NULL),
    ('glm-4.5v', 'zhipu', 'GLM-4.5V', 10, NULL, NULL),
    ('glm-4.6v', 'zhipu', 'GLM-4.6V', 10, NULL, NULL),
    ('glm-4.5-air', 'zhipu', 'GLM-4.5 Air', 5, NULL, NULL),
    ('glm-4.5-airx', 'zhipu', 'GLM-4.5 AirX', 5, NULL, NULL),
    ('glm-4.5-flash', 'zhipu', 'GLM-4.5 Flash', 2, NULL, NULL),
    ('glm-4.7', 'zhipu', 'GLM-4.7', 3, NULL, NULL),
    ('glm-4.6', 'zhipu', 'GLM-4.6', 3, NULL, NULL),
    ('glm-4.6v-flashx', 'zhipu', 'GLM-4.6V FlashX', 3, NULL, NULL),
    ('glm-4.7-flashx', 'zhipu', 'GLM-4.7 FlashX', 3, NULL, NULL),
    ('glm-4.7-flash', 'zhipu', 'GLM-4.7 Flash', 1, NULL, NULL),
    ('glm-5', 'zhipu', 'GLM-5', 1, NULL, NULL),
    ('glm-4.6v-flash', 'zhipu', 'GLM-4.6V Flash', 1, NULL, NULL)
ON CONFLICT (model_id) DO NOTHING;

-- Insert Kimi rate limits (estimates)
INSERT INTO model_capacity (model_id, provider, display_name, concurrent_limit, tpm_limit, rpm_limit) VALUES
    ('kimi-k2.5', 'moonshot', 'Kimi K2.5', 5, NULL, NULL),
    ('kimi-k2-thinking', 'moonshot', 'Kimi K2 Thinking', 3, NULL, NULL)
ON CONFLICT (model_id) DO NOTHING;

-- Insert Gemini rate limits (very high)
INSERT INTO model_capacity (model_id, provider, display_name, concurrent_limit, tpm_limit, rpm_limit) VALUES
    ('gemini-3-flash', 'google', 'Gemini 3 Flash', 60, NULL, NULL),
    ('gemini-3-pro', 'google', 'Gemini 3 Pro', 60, NULL, NULL)
ON CONFLICT (model_id) DO NOTHING;

-- Request tracking table
CREATE TABLE IF NOT EXISTS llm_requests (
    id SERIAL PRIMARY KEY,
    request_id UUID DEFAULT gen_random_uuid(),
    model_id VARCHAR(50) REFERENCES model_capacity(model_id),
    status VARCHAR(20) DEFAULT 'pending', -- pending, active, completed, failed
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_llm_requests_model ON llm_requests(model_id);
CREATE INDEX IF NOT EXISTS idx_llm_requests_status ON llm_requests(status);
CREATE INDEX IF NOT EXISTS idx_llm_requests_started ON llm_requests(started_at);

-- Function to update last_updated timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_model_capacity_modtime
    BEFORE UPDATE ON model_capacity
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();
