-- Migration 008: Add Renovation Ops core tables

CREATE TABLE IF NOT EXISTS renovations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  building_id UUID NOT NULL REFERENCES buildings(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'planned',
  readiness_state TEXT NOT NULL DEFAULT 'not_started',
  start_date DATE,
  target_end_date DATE,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS renovations_unit_id_unique ON renovations(unit_id);
CREATE INDEX IF NOT EXISTS renovations_building_id_idx ON renovations(building_id);
CREATE INDEX IF NOT EXISTS renovations_status_idx ON renovations(status);
CREATE INDEX IF NOT EXISTS renovations_readiness_state_idx ON renovations(readiness_state);

CREATE TABLE IF NOT EXISTS renovation_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  renovation_record_id UUID NOT NULL REFERENCES renovations(id) ON DELETE CASCADE,
  assignee_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'todo',
  due_date DATE,
  completed_at TIMESTAMP,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS renovation_tasks_renovation_record_id_idx ON renovation_tasks(renovation_record_id);
CREATE INDEX IF NOT EXISTS renovation_tasks_status_idx ON renovation_tasks(status);
CREATE INDEX IF NOT EXISTS renovation_tasks_assignee_employee_id_idx ON renovation_tasks(assignee_employee_id);

CREATE TABLE IF NOT EXISTS renovation_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  renovation_record_id UUID NOT NULL REFERENCES renovations(id) ON DELETE CASCADE,
  task_id UUID REFERENCES renovation_tasks(id) ON DELETE SET NULL,
  vendor_name TEXT NOT NULL,
  item_name TEXT NOT NULL,
  quantity_ordered INTEGER NOT NULL,
  quantity_received INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft',
  ordered_at DATE,
  expected_at DATE,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS renovation_orders_renovation_record_id_idx ON renovation_orders(renovation_record_id);
CREATE INDEX IF NOT EXISTS renovation_orders_task_id_idx ON renovation_orders(task_id);
CREATE INDEX IF NOT EXISTS renovation_orders_status_idx ON renovation_orders(status);

CREATE TABLE IF NOT EXISTS renovation_receiving_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES renovation_orders(id) ON DELETE CASCADE,
  quantity_received INTEGER NOT NULL,
  received_at TIMESTAMP NOT NULL DEFAULT NOW(),
  notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS renovation_receiving_events_order_id_idx ON renovation_receiving_events(order_id);

CREATE TABLE IF NOT EXISTS renovation_surplus_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  renovation_record_id UUID NOT NULL REFERENCES renovations(id) ON DELETE CASCADE,
  source_order_id UUID REFERENCES renovation_orders(id) ON DELETE SET NULL,
  task_id UUID REFERENCES renovation_tasks(id) ON DELETE SET NULL,
  item_name TEXT NOT NULL,
  quantity_available INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'available',
  location TEXT,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS renovation_surplus_items_renovation_record_id_idx ON renovation_surplus_items(renovation_record_id);
CREATE INDEX IF NOT EXISTS renovation_surplus_items_source_order_id_idx ON renovation_surplus_items(source_order_id);
CREATE INDEX IF NOT EXISTS renovation_surplus_items_status_idx ON renovation_surplus_items(status);
