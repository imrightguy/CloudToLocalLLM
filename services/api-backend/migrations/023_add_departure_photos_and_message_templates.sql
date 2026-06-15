-- Migration 023: Departure/Arrival photos + customizable message templates
-- Powers PlexFlow webhooks → automatic SMS/email on tenant move-out / move-in.

-- ─── Departure / Arrival photos ───
CREATE TABLE IF NOT EXISTS departure_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
  unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
  tenant_name TEXT,
  event_type TEXT NOT NULL DEFAULT 'departure', -- departure | arrival
  photo_url TEXT,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS departure_photos_building_id_idx ON departure_photos(building_id);
CREATE INDEX IF NOT EXISTS departure_photos_unit_id_idx ON departure_photos(unit_id);
CREATE INDEX IF NOT EXISTS departure_photos_event_type_idx ON departure_photos(event_type);

-- ─── Customizable message templates (one row per webhook event type) ───
CREATE TABLE IF NOT EXISTS message_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL UNIQUE, -- tenant_deactivated | tenant_activated | lease_created | lease_renewed | unit_vacant | unit_occupied
  channel TEXT NOT NULL DEFAULT 'sms', -- sms | email
  subject TEXT, -- email only
  body TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Default templates (Quebec French). Placeholders: {tenantName} {unitLabel} {buildingName} {date}
INSERT INTO message_templates (event_type, channel, subject, body) VALUES
  ('tenant_deactivated', 'sms', NULL,
   'Bonjour {tenantName}, votre départ du {unitLabel} est prévu le {date}. Prenez des photos de l''état du logement et envoyez-les ici. Merci! — Simon Gravel'),
  ('tenant_activated', 'sms', NULL,
   'Bienvenue {tenantName} au {unitLabel}! Votre bail débute le {date}. Prenez des photos de votre arrivée pour l''état des lieux. Des questions? Contactez-moi. — Simon Gravel'),
  ('lease_created', 'sms', NULL,
   'Bonjour {tenantName}, votre bail au {unitLabel} est confirmé et débute le {date}. Bienvenue! — Simon Gravel'),
  ('lease_renewed', 'sms', NULL,
   'Bonjour {tenantName}, votre bail au {unitLabel} a été renouvelé jusqu''au {date}. Merci de votre confiance! — Simon Gravel'),
  ('unit_vacant', 'email', 'Unité vacante — {unitLabel}',
   '{unitLabel} ({buildingName}) sera vacant dès le {date}. Locataire sortant: {tenantName}. Action: mettre en annonce.'),
  ('unit_occupied', 'email', 'Unité occupée — {unitLabel}',
   '{unitLabel} ({buildingName}) est maintenant occupé par {tenantName}. Bail début: {date}.')
ON CONFLICT (event_type) DO NOTHING;
