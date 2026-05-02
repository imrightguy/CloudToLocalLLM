const { eq } = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  renovationsTable,
  renovationTasksTable,
  workerIntakeRecordsTable,
  unitReadinessTable,
  unitsTable,
} = require('../database/schema');

const BLOCKING_MESSAGE_KINDS = new Set(['blocker', 'missing_material']);
const RESOLVED_INTAKE_STATUSES = new Set(['resolved', 'dismissed']);
const READY_READINESS_STATES = new Set(['ready_for_leasing', 'ready']);

const toIsoOrNull = (value) => {
  if (!value) { return null; }
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const summarizeBlockers = (blockingTasks, blockingIntakes) => {
  const labels = [
    ...blockingTasks.map((task) => `Tâche bloquée: ${task.title}`),
    ...blockingIntakes.map((intake) => {
      const details = intake.summary || intake.messageBody || intake.messageKind;
      return `Message ouvrier: ${details}`;
    }),
  ];

  if (!labels.length) { return null; }
  return labels.slice(0, 3).join(' · ');
};

const deriveOpsStatus = (renovationRecord, blockingCount) => {
  if (!renovationRecord) { return 'not_started'; }
  if (['completed', 'archived'].includes(renovationRecord.status)) { return 'closed'; }
  if (renovationRecord.status === 'blocked' || renovationRecord.readinessState === 'blocked' || blockingCount > 0) {
    return 'blocked';
  }
  if (renovationRecord.readinessState === 'ready_to_list') { return 'ready_to_list'; }
  if (renovationRecord.readinessState === 'ready_for_leasing') { return 'ready_for_leasing'; }
  if (renovationRecord.readinessState === 'ready') { return 'ready'; }
  if (renovationRecord.status === 'active' || renovationRecord.readinessState === 'in_progress') { return 'active'; }
  return renovationRecord.status || renovationRecord.readinessState || 'not_started';
};

const deriveLeasingStatus = (renovationRecord) => {
  if (!renovationRecord) { return 'not_ready'; }
  return READY_READINESS_STATES.has(renovationRecord.readinessState) ? 'ready' : 'not_ready';
};

const deriveReadinessProjection = ({
  renovationRecord = null,
  tasks = [],
  intakes = [],
  existingReadiness = null,
  now = new Date(),
}) => {
  const blockingTasks = tasks.filter((task) => task && task.status === 'blocked');
  const blockingIntakes = intakes.filter((intake) => intake
    && BLOCKING_MESSAGE_KINDS.has(intake.messageKind)
    && !RESOLVED_INTAKE_STATUSES.has(intake.status));
  const blockingCount = blockingTasks.length + blockingIntakes.length;
  const opsStatus = deriveOpsStatus(renovationRecord, blockingCount);
  const leasingStatus = deriveLeasingStatus(renovationRecord);
  const blockingSummary = summarizeBlockers(blockingTasks, blockingIntakes);
  const readyAt = existingReadiness?.readyAt || (leasingStatus === 'ready' ? now : null);

  return {
    unitId: renovationRecord?.unitId || existingReadiness?.unitId || null,
    currentRenovationRecordId: renovationRecord?.id || existingReadiness?.currentRenovationRecordId || null,
    opsStatus,
    leasingStatus,
    blockingCount,
    blockingSummary,
    readyAt,
    handedOffAt: existingReadiness?.handedOffAt || null,
    leasedAt: existingReadiness?.leasedAt || null,
    updatedAt: now,
  };
};

const loadRenovationReadinessContext = async (unitId) => {
  const [unit] = await db.select().from(unitsTable).where(eq(unitsTable.id, unitId)).limit(1);
  if (!unit) { return null; }

  const [renovationRecord] = await db.select().from(renovationsTable).where(eq(renovationsTable.unitId, unitId)).limit(1);
  const tasks = renovationRecord
    ? await db.select().from(renovationTasksTable).where(eq(renovationTasksTable.renovationRecordId, renovationRecord.id))
    : [];
  const intakes = renovationRecord
    ? await db.select().from(workerIntakeRecordsTable).where(eq(workerIntakeRecordsTable.renovationRecordId, renovationRecord.id))
    : [];
  const [existingReadiness] = await db.select().from(unitReadinessTable).where(eq(unitReadinessTable.unitId, unitId)).limit(1);

  return {
    unit,
    renovationRecord: renovationRecord || null,
    tasks,
    intakes,
    existingReadiness: existingReadiness || null,
  };
};

const persistReadinessProjection = async (projection, existingReadiness) => {
  const values = {
    unitId: projection.unitId,
    currentRenovationRecordId: projection.currentRenovationRecordId,
    opsStatus: projection.opsStatus,
    leasingStatus: projection.leasingStatus,
    blockingCount: projection.blockingCount,
    blockingSummary: projection.blockingSummary,
    readyAt: projection.readyAt,
    handedOffAt: projection.handedOffAt,
    leasedAt: projection.leasedAt,
    updatedAt: projection.updatedAt,
  };

  if (existingReadiness) {
    const [updated] = await db.update(unitReadinessTable)
      .set(values)
      .where(eq(unitReadinessTable.unitId, projection.unitId))
      .returning();
    return updated || null;
  }

  const [created] = await db.insert(unitReadinessTable).values({
    ...values,
    createdAt: projection.updatedAt,
  }).returning();
  return created || null;
};

const syncReadinessProjectionByUnitId = async (unitId) => {
  const context = await loadRenovationReadinessContext(unitId);
  if (!context) { return null; }

  const projection = deriveReadinessProjection({
    renovationRecord: context.renovationRecord,
    tasks: context.tasks,
    intakes: context.intakes,
    existingReadiness: context.existingReadiness,
    now: new Date(),
  });

  return persistReadinessProjection(projection, context.existingReadiness);
};

const syncReadinessProjectionByRenovationRecordId = async (renovationRecordId) => {
  const [renovationRecord] = await db.select().from(renovationsTable).where(eq(renovationsTable.id, renovationRecordId)).limit(1);
  if (!renovationRecord) { return null; }
  return syncReadinessProjectionByUnitId(renovationRecord.unitId);
};

const loadUnitReadinessByUnitId = async (unitId) => {
  let [unitReadiness] = await db.select().from(unitReadinessTable).where(eq(unitReadinessTable.unitId, unitId)).limit(1);
  if (unitReadiness) { return unitReadiness; }
  await syncReadinessProjectionByUnitId(unitId);
  [unitReadiness] = await db.select().from(unitReadinessTable).where(eq(unitReadinessTable.unitId, unitId)).limit(1);
  return unitReadiness || null;
};

module.exports = {
  deriveReadinessProjection,
  syncReadinessProjectionByUnitId,
  syncReadinessProjectionByRenovationRecordId,
  loadUnitReadinessByUnitId,
};
