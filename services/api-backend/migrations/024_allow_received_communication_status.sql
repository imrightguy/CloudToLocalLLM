-- Migration 016: Allow inbound Messenger/SMS receipt status in communication_logs

DO $$
DECLARE
  constraint_name text;
BEGIN
  FOR constraint_name IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    WHERE rel.relname = 'communication_logs'
      AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) ILIKE '%status%'
  LOOP
    EXECUTE format('ALTER TABLE communication_logs DROP CONSTRAINT %I', constraint_name);
  END LOOP;
END $$;

ALTER TABLE communication_logs
  ADD CONSTRAINT communication_logs_status_check
  CHECK (status IN ('sent', 'delivered', 'read', 'failed', 'received'));
