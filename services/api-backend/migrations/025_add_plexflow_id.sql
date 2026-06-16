-- Add plexflow_id to buildings and units for PlexFlow integration
ALTER TABLE buildings ADD COLUMN IF NOT EXISTS plexflow_id UUID UNIQUE;
ALTER TABLE units ADD COLUMN IF NOT EXISTS plexflow_id UUID UNIQUE;
CREATE UNIQUE INDEX IF NOT EXISTS buildings_plexflow_id_idx ON buildings(plexflow_id);
CREATE UNIQUE INDEX IF NOT EXISTS units_plexflow_id_idx ON units(plexflow_id);
