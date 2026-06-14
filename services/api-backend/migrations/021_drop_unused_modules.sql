BEGIN;

DROP TABLE IF EXISTS dossier_case_items CASCADE;
DROP TABLE IF EXISTS dossier_cases CASCADE;

DROP TABLE IF EXISTS tenant_checklist_events CASCADE;
DROP TABLE IF EXISTS tenant_checklist_attachments CASCADE;
DROP TABLE IF EXISTS tenant_checklist_signatures CASCADE;
DROP TABLE IF EXISTS tenant_checklist_steps CASCADE;
DROP TABLE IF EXISTS tenant_checklist_sessions CASCADE;

DROP TABLE IF EXISTS documents_leads CASCADE;
DROP TABLE IF EXISTS documents CASCADE;

DROP TABLE IF EXISTS whatsapp_conversations CASCADE;
DROP TABLE IF EXISTS messenger_conversations CASCADE;

DROP TABLE IF EXISTS observation_results CASCADE;

COMMIT;
