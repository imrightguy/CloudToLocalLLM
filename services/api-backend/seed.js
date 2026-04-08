const bcrypt = require('bcryptjs');

const { db } = require('./src/database/connection');
const { usersTable, employeesTable, buildingsTable, unitsTable, employeeAssignmentsTable, employeeSchedulesTable, leadsTable } = require('./src/database/schema');

const seed = async () => {
  console.log('🌱 Seeding ImmoGestion database...');

  // 1. Admin user — Simon
  const passwordHash = await bcrypt.hash('admin123', 12);
  const [simon] = await db.insert(usersTable).values({
    email: 'simon@immogestion.ca',
    passwordHash,
    firstName: 'Simon',
    lastName: 'Maltais',
    phone: '+15141234567',
    role: 'admin',
    emailVerified: true,
  }).returning();

  console.log(`✅ User: ${simon.email}`);

  // 2. Employees
  const [marc] = await db.insert(employeesTable).values({ firstName: 'Marc', lastName: 'Tremblay', phone: '+15149876543' }).returning();
  const [sophie] = await db.insert(employeesTable).values({ firstName: 'Sophie', lastName: 'Gagnon', phone: '+15149876544' }).returning();
  const [jean] = await db.insert(employeesTable).values({ firstName: 'Jean', lastName: 'Bouchard', phone: '+15149876545' }).returning();

  console.log(`✅ Employees: ${marc.firstName}, ${sophie.firstName}, ${jean.firstName}`);

  // 3. Buildings
  const [b1] = await db.insert(buildingsTable).values({
    name: '1200 Rachel Est', address: '1200 Rue Rachel Est', city: 'Montréal', province: 'QC', postalCode: 'H2J 2J3',
    totalUnits: 8, occupiedUnits: 5, description: 'Immeuble de 8 logements au Plateau',
    properties: { yearBuilt: 1925, parking: true, laundry: 'shared' },
  }).returning();
  const [b2] = await db.insert(buildingsTable).values({
    name: '4520 Boul. St-Laurent', address: '4520 Boul. Saint-Laurent', city: 'Montréal', province: 'QC', postalCode: 'H2W 1Y3',
    totalUnits: 12, occupiedUnits: 9, description: 'Immeuble de 12 logements dans le Mile End',
    properties: { yearBuilt: 1940, parking: false, laundry: 'in-unit' },
  }).returning();
  const [b3] = await db.insert(buildingsTable).values({
    name: '3100 Rue Ontario', address: '3100 Rue Ontario Est', city: 'Montréal', province: 'QC', postalCode: 'H1W 1P2',
    totalUnits: 6, occupiedUnits: 3, description: 'Immeuble de 6 logements à Hochelaga',
    properties: { yearBuilt: 1960, parking: true, laundry: 'shared' },
  }).returning();

  console.log(`✅ Buildings: ${b1.name}, ${b2.name}, ${b3.name}`);

  // 4. Units
  const units = [
    { buildingId: b1.id, label: '1', rentCents: 85000, status: 'occupied', bedrooms: 2, bathrooms: 1, squareFeet: 800 },
    { buildingId: b1.id, label: '2', rentCents: 77500, status: 'occupied', bedrooms: 1, bathrooms: 1, squareFeet: 550 },
    { buildingId: b1.id, label: '3', rentCents: 92500, status: 'vacant', bedrooms: 3, bathrooms: 1, squareFeet: 1000 },
    { buildingId: b1.id, label: '4', rentCents: 82500, status: 'occupied', bedrooms: 2, bathrooms: 1, squareFeet: 750 },
    { buildingId: b2.id, label: '101', rentCents: 110000, status: 'occupied', bedrooms: 2, bathrooms: 1, squareFeet: 900 },
    { buildingId: b2.id, label: '202', rentCents: 97500, status: 'vacant', bedrooms: 1, bathrooms: 1, squareFeet: 600 },
    { buildingId: b2.id, label: '303', rentCents: 125000, status: 'occupied', bedrooms: 3, bathrooms: 2, squareFeet: 1100 },
    { buildingId: b3.id, label: 'A', rentCents: 65000, status: 'vacant', bedrooms: 1, bathrooms: 1, squareFeet: 450 },
    { buildingId: b3.id, label: 'B', rentCents: 72000, status: 'occupied', bedrooms: 1, bathrooms: 1, squareFeet: 500 },
  ];
  const insertedUnits = await db.insert(unitsTable).values(units).returning();
  console.log(`✅ Units: ${insertedUnits.length} created`);

  // 5. Employee assignments
  await db.insert(employeeAssignmentsTable).values([
    { employeeId: marc.id, buildingId: b1.id, role: 'primary' },
    { employeeId: marc.id, buildingId: b2.id, role: 'backup' },
    { employeeId: sophie.id, buildingId: b2.id, role: 'primary' },
    { employeeId: sophie.id, buildingId: b3.id, role: 'primary' },
    { employeeId: jean.id, buildingId: b1.id, role: 'backup' },
    { employeeId: jean.id, buildingId: b3.id, role: 'backup' },
  ]);
  console.log('✅ Employee assignments created');

  // 6. Weekly schedules (Mon-Fri 9-17)
  const scheduleEntries = [];
  for (const emp of [marc, sophie]) {
    for (let day = 0; day <= 4; day++) {
      scheduleEntries.push({ employeeId: emp.id, buildingId: emp.id === marc.id ? b1.id : b2.id, dayOfWeek: day, startTime: '09:00', endTime: '17:00' });
    }
  }
  await db.insert(employeeSchedulesTable).values(scheduleEntries);
  console.log(`✅ Schedules: ${scheduleEntries.length} entries`);

  // 7. Sample leads
  await db.insert(leadsTable).values([
    { fullName: 'Marie Dupont', phone: '+15141112222', email: 'marie.dupont@email.com', source: 'facebook', stage: 'contacte', language: 'fr', buildingId: b1.id, notes: 'Intéressée par un 3½' },
    { fullName: 'Alex Chen', phone: '+15141113333', email: 'alex.chen@email.com', source: 'website', stage: 'visite_planifiee', language: 'fr', buildingId: b2.id, assignedEmployeeId: sophie.id },
    { fullName: 'Sarah Johnson', phone: '+15141114444', source: 'referral', stage: 'nouveau', language: 'en', buildingId: b3.id },
  ]);
  console.log('✅ Sample leads created');

  console.log('\n🎉 Seed complete!');
  process.exit(0);
};

seed().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});
