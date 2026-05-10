require('dotenv').config();
const path = require('path');
const fs = require('fs');
const { connect, db, closeDatabase } = require('../src/database/connection');
const { eq, sql } = require('drizzle-orm');
const {
  buildingsTable, unitsTable, employeesTable, employeeAssignmentsTable,
  employeeSchedulesTable, leadsTable, visitsTable, leasesTable,
  communicationLogsTable, smsLogsTable, paymentsTable, usersTable,
} = require('../src/database/schema');

const SEED_TAG = '__DEMO_SEED__';
const bcrypt = require('bcryptjs');

const loadData = (filename) => JSON.parse(
  fs.readFileSync(path.join(__dirname, 'seed-data', filename), 'utf8'),
);

const seedBuildings = async (ids) => {
  const buildings = loadData('buildings.json');
  const rows = await db.insert(buildingsTable).values(
    buildings.map((b) => ({
      ...b,
      occupiedUnits: 0,
      properties: { [SEED_TAG]: true },
    })),
  ).onConflictDoNothing({ target: buildingsTable.name }).returning();
  ids.buildings = rows.map((r) => r.id);
  if (rows.length < buildings.length) {
    const existing = await db.select({ id: buildingsTable.id }).from(buildingsTable)
      .where(eq(buildingsTable.name, buildings[0].name));
    ids.buildings = existing.map((r) => r.id);
  }
  console.log(`  Buildings: ${ids.buildings.length} created/found`);
};

const seedUnits = async (ids) => {
  const units = loadData('units.json');
  const rows = [];
  for (const u of units) {
    const buildingId = ids.buildings[u.buildingIndex];
    const [row] = await db.insert(unitsTable).values({
      buildingId,
      label: u.label,
      rentCents: u.rentCents,
      status: u.status,
      bedrooms: u.bedrooms,
      bathrooms: u.bathrooms,
      squareFeet: u.squareFeet,
      description: u.description,
      amenities: u.amenities || {},
      tenantName: u.tenantName || null,
      tenantPhone: u.tenantPhone || null,
      tenantLeaseEnd: u.tenantLeaseEnd ? new Date(u.tenantLeaseEnd) : null,
    }).onConflictDoNothing({ target: [unitsTable.buildingId, unitsTable.label] }).returning();
    if (row) rows.push(row);
  }
  if (rows.length < units.length) {
    const all = await db.select({ id: unitsTable.id, buildingId: unitsTable.buildingId, label: unitsTable.label })
      .from(unitsTable);
    ids.units = all.map((r) => r.id);
  } else {
    ids.units = rows.map((r) => r.id);
  }
  console.log(`  Units: ${ids.units.length} created/found`);
};

const seedEmployees = async (ids) => {
  const employees = loadData('employees.json');
  const rows = [];
  for (const e of employees) {
    const [row] = await db.insert(employeesTable).values({
      firstName: e.firstName,
      lastName: e.lastName,
      phone: e.phone,
      email: e.email || null,
    }).onConflictDoNothing({ target: employeesTable.phone }).returning();
    if (row) rows.push(row);
  }
  if (rows.length < employees.length) {
    const all = await db.select({ id: employeesTable.id }).from(employeesTable);
    ids.employees = all.slice(-employees.length).map((r) => r.id);
  } else {
    ids.employees = rows.map((r) => r.id);
  }
  console.log(`  Employees: ${ids.employees.length} created/found`);
};

const seedEmployeeAssignments = async (ids) => {
  const assignments = loadData('employee-assignments.json');
  let count = 0;
  for (const a of assignments) {
    const employeeId = ids.employees[a.employeeIndex];
    const buildingId = ids.buildings[a.buildingIndex];
    if (!employeeId || !buildingId) continue;
    const [row] = await db.insert(employeeAssignmentsTable).values({
      employeeId,
      buildingId,
      role: a.role,
    }).onConflictDoNothing({ target: [employeeAssignmentsTable.employeeId, employeeAssignmentsTable.buildingId] }).returning();
    if (row) count++;
  }
  console.log(`  Employee Assignments: ${count} created`);
};

const seedEmployeeSchedules = async (ids) => {
  const schedules = loadData('employee-schedules.json');
  let count = 0;
  for (const s of schedules) {
    const employeeId = ids.employees[s.employeeIndex];
    const buildingId = ids.buildings[s.buildingIndex];
    if (!employeeId || !buildingId) continue;
    const [row] = await db.insert(employeeSchedulesTable).values({
      employeeId,
      buildingId,
      dayOfWeek: s.dayOfWeek,
      startTime: s.startTime,
      endTime: s.endTime,
    }).onConflictDoNothing({ target: [employeeSchedulesTable.employeeId, employeeSchedulesTable.buildingId, employeeSchedulesTable.dayOfWeek] }).returning();
    if (row) count++;
  }
  console.log(`  Employee Schedules: ${count} created`);
};

const seedLeads = async (ids) => {
  const leads = loadData('leads.json');
  const rows = [];
  for (const l of leads) {
    const assignedEmployeeId = ids.employees[l.assignedEmployeeIndex] || null;
    const buildingId = ids.buildings[l.buildingIndex] || null;
    const [row] = await db.insert(leadsTable).values({
      fullName: l.fullName,
      email: l.email || null,
      phone: l.phone || null,
      budgetCents: l.budgetCents || null,
      desiredUnit: l.desiredUnit || null,
      source: l.source,
      stage: l.stage,
      qualificationState: l.qualificationState || null,
      qualificationReasonCode: l.qualificationReasonCode || null,
      qualificationReasonNote: l.qualificationReasonNote || null,
      notes: l.notes || null,
      language: l.language || 'fr',
      assignedEmployeeId,
      buildingId,
      tags: { [SEED_TAG]: true },
    }).onConflictDoNothing({ target: leadsTable.phone }).returning();
    if (row) rows.push(row);
  }
  if (rows.length < leads.length) {
    const all = await db.select({ id: leadsTable.id }).from(leadsTable);
    ids.leads = all.slice(-leads.length).map((r) => r.id);
  } else {
    ids.leads = rows.map((r) => r.id);
  }
  console.log(`  Leads: ${ids.leads.length} created/found`);
};

const seedVisits = async (ids) => {
  const visits = loadData('visits.json');
  let count = 0;
  for (const v of visits) {
    const unitId = ids.units[v.unitIndex];
    const employeeId = ids.employees[v.employeeIndex];
    const leadId = ids.leads[v.leadIndex];
    if (!unitId || !employeeId || !leadId) continue;
    const [row] = await db.insert(visitsTable).values({
      unitId,
      employeeId,
      leadId,
      dateTime: new Date(v.dateTime),
      durationMinutes: v.durationMinutes,
      status: v.status,
      tenantConfirmed: v.tenantConfirmed,
      occupantNotified: v.occupantNotified,
      employeeConfirmed: v.employeeConfirmed,
      morningOfSent: v.morningOfSent,
      confirmationToken: v.status === 'scheduled' ? `demo-${Date.now()}-${count}` : null,
      outcome: v.outcome,
      notes: v.notes || null,
    }).onConflictDoNothing({ target: [visitsTable.unitId, visitsTable.leadId, visitsTable.dateTime] }).returning();
    if (row) count++;
  }
  console.log(`  Visits: ${count} created`);
};

const seedLeases = async (ids) => {
  const leases = loadData('leases.json');
  const leaseRows = [];
  let count = 0;
  for (const l of leases) {
    const unitId = ids.units[l.unitIndex];
    const leadId = l.leadIndex !== null ? ids.leads[l.leadIndex] : null;
    if (!unitId) continue;
    const values = {
      unitId,
      tenantFirstName: l.tenantFirstName,
      tenantLastName: l.tenantLastName,
      tenantEmail: l.tenantEmail || null,
      tenantPhone: l.tenantPhone || null,
      rentCents: l.rentCents,
      depositCents: l.depositCents,
      startDate: new Date(l.startDate),
      endDate: new Date(l.endDate),
      status: l.status,
      terms: l.terms || {},
    };
    if (leadId) values.leadId = leadId;
    if (l.signedAt) values.signedAt = new Date(l.signedAt);
    const [row] = await db.insert(leasesTable).values(values)
      .onConflictDoNothing({ target: [leasesTable.unitId, leasesTable.tenantFirstName, leasesTable.tenantLastName, leasesTable.startDate] })
      .returning();
    if (row) {
      count++;
      leaseRows.push(row);
    } else {
      const [existing] = await db.select({ id: leasesTable.id }).from(leasesTable)
        .where(eq(leasesTable.unitId, unitId)).limit(1);
      if (existing) leaseRows.push(existing);
    }
  }
  ids.leases = leaseRows.map((r) => r.id);
  console.log(`  Leases: ${count} created, ${ids.leases.length} total`);
};

const seedCommunications = async (ids) => {
  const comms = loadData('communications.json');
  let count = 0;
  for (const c of comms) {
    const leadId = ids.leads[c.leadIndex];
    const employeeId = ids.employees[c.employeeIndex];
    if (!leadId || !employeeId) continue;
    const [row] = await db.insert(communicationLogsTable).values({
      leadId,
      employeeId,
      type: c.type,
      direction: c.direction,
      content: c.content,
      status: c.status || 'sent',
      createdAt: new Date(c.createdAt),
    }).returning();
    if (row) count++;
  }
  console.log(`  Communications: ${count} created`);
};

const seedSmsLogs = async (ids) => {
  const logs = loadData('sms-logs.json');
  let count = 0;
  for (const l of logs) {
    const leadId = ids.leads[l.leadIndex];
    const employeeId = ids.employees[l.employeeIndex];
    if (!leadId || !employeeId) continue;
    const [row] = await db.insert(smsLogsTable).values({
      leadId,
      employeeId,
      phoneNumber: l.phoneNumber,
      direction: l.direction,
      messageBody: l.messageBody,
      status: l.status,
      twilioStatus: l.twilioStatus || null,
    }).returning();
    if (row) count++;
  }
  console.log(`  SMS Logs: ${count} created`);
};

const seedPayments = async (ids) => {
  const payments = loadData('payments.json');
  let count = 0;
  for (const p of payments) {
    const leaseId = ids.leases[p.leaseIndex];
    if (!leaseId) continue;
    const values = {
      leaseId,
      amountCents: p.amountCents,
      lateFeeCents: p.lateFeeCents || 0,
      dueDate: new Date(p.dueDate),
      status: p.status,
      method: p.method || null,
      reference: p.reference || null,
    };
    if (p.paidDate) values.paidDate = new Date(p.paidDate);
    const [row] = await db.insert(paymentsTable).values(values).returning();
    if (row) count++;
  }
  console.log(`  Payments: ${count} created`);
};

const seedDemoUser = async () => {
  const email = process.env.DEMO_USER_EMAIL || 'demo@immogestion.app';
  const password = process.env.DEMO_USER_PASSWORD || 'Demo2025!';
  const existing = await db.select({ id: usersTable.id }).from(usersTable)
    .where(eq(usersTable.email, email)).limit(1);
  if (existing.length) {
    console.log(`  Demo user: already exists (${email})`);
    return;
  }
  const passwordHash = await bcrypt.hash(password, 12);
  await db.insert(usersTable).values({
    email,
    passwordHash,
    firstName: 'Demo',
    lastName: 'Utilisateur',
    role: 'admin',
    isActive: true,
    emailVerified: true,
  });
  console.log(`  Demo user: created (${email})`);
};

const updateBuildingOccupancy = async (ids) => {
  for (const buildingId of ids.buildings) {
    const occupiedUnits = await db.select({ count: sql`count(*)::int` })
      .from(unitsTable)
      .where(eq(unitsTable.buildingId, buildingId));
    await db.update(buildingsTable)
      .set({ occupiedUnits: occupiedUnits[0].count })
      .where(eq(buildingsTable.id, buildingId));
  }
  console.log('  Building occupancy updated');
};

const seedDemoData = async () => {
  console.log('Connecting to database...');
  await connect();
  console.log('Seeding demo data...\n');

  const ids = { buildings: [], units: [], employees: [], leads: [], leases: [] };

  await seedBuildings(ids);
  await seedUnits(ids);
  await seedEmployees(ids);
  await seedEmployeeAssignments(ids);
  await seedEmployeeSchedules(ids);
  await seedLeads(ids);
  await seedVisits(ids);
  await seedLeases(ids);
  await seedPayments(ids);
  await seedCommunications(ids);
  await seedSmsLogs(ids);
  await updateBuildingOccupancy(ids);
  await seedDemoUser();

  console.log('\nDemo data seeding completed!');
  await closeDatabase();
};

const clearDemoData = async () => {
  console.log('Connecting to database...');
  await connect();
  console.log('Clearing demo data...\n');

  const tablesToClean = [
    'payments', 'sms_logs', 'communication_logs', 'visits', 'leases',
    'leads', 'employee_schedules', 'employee_assignments',
    'units', 'employees', 'buildings',
  ];

  const client = await (await import('pg')).default.Pool;
  const pool = new client({ connectionString: process.env.DATABASE_URL });
  const conn = await pool.connect();
  try {
    await conn.query('SET session_replication_role = replica');
    for (const table of tablesToClean) {
      try {
        await conn.query(`DELETE FROM ${table}`);
        console.log(`  Cleared: ${table}`);
      } catch (e) {
        console.log(`  Skipped: ${table} (${e.message})`);
      }
    }
    await conn.query('SET session_replication_role = DEFAULT');
  } finally {
    conn.release();
    await pool.end();
  }

  console.log('\nDemo data cleared!');
  await closeDatabase();
};

if (require.main === module) {
  const command = process.argv[2];
  if (command === '--clear') {
    clearDemoData().then(() => process.exit(0)).catch((err) => {
      console.error('Clear failed:', err);
      process.exit(1);
    });
  } else {
    seedDemoData().then(() => process.exit(0)).catch((err) => {
      console.error('Seed failed:', err);
      process.exit(1);
    });
  }
}

module.exports = { seedDemoData, clearDemoData };
