-- Create additional users and permissions for the application
-- This script will be executed inside the PostgreSQL pod
-- NOTE: The main POSTGRES_USER is created automatically by PostgreSQL from environment variables

-- Connect to the database
\c CloudToLocalLLM

-- Grant all privileges on all current and future tables to the main user
-- The main user (from POSTGRES_USER env var) already exists and has ownership
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO :POSTGRES_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO :POSTGRES_USER;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO :POSTGRES_USER;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO :POSTGRES_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO :POSTGRES_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO :POSTGRES_USER;

-- Create additional application user if needed (uncomment and modify as required)
-- CREATE USER appuser WITH PASSWORD 'CHANGE_THIS_PASSWORD';
-- GRANT CONNECT ON DATABASE CloudToLocalLLM TO appuser;
-- GRANT USAGE ON SCHEMA public TO appuser;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO appuser;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO appuser;

-- Verify users
\du
