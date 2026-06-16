const { eq, and } = require("drizzle-orm");
const { db } = require("../database/connection");
const {
  unitsTable,
  buildingsTable,
  unitReadinessTable,
} = require("../database/schema");
const { invalidate } = require("../utils/cache");
const logger = require("../utils/logger");

/**
 * When a unit reaches leasing readiness, mark it as available.
 * Called automatically when readinessState transitions to ready_for_leasing or ready.
 */
async function onUnitReadyForLeasing(unitId) {
  const [readiness] = await db
    .select()
    .from(unitReadinessTable)
    .where(eq(unitReadinessTable.unitId, unitId))
    .limit(1);

  if (!readiness || readiness.leasingStatus !== "ready") {
    return null;
  }

  // Mark unit as ready_for_leasing
  const [updated] = await db
    .update(unitsTable)
    .set({ status: "ready_for_leasing", updatedAt: new Date() })
    .where(eq(unitsTable.id, unitId))
    .returning();

  // Set handedOffAt if not already set
  if (!readiness.handedOffAt) {
    await db
      .update(unitReadinessTable)
      .set({ handedOffAt: new Date(), updatedAt: new Date() })
      .where(eq(unitReadinessTable.unitId, unitId));
  }

  invalidate("analytics:*");
  invalidate("plexflow:*");

  logger.info("[leasing-readiness] Unit marked ready for leasing", {
    unitId,
    label: updated?.label,
  });

  return updated || null;
}

/**
 * List all units ready for leasing, optionally filtered by building.
 */
async function listUnitsReadyForLeasing(buildingId = null) {
  const conditions = [
    eq(unitReadinessTable.leasingStatus, "ready"),
    eq(unitsTable.isActive, true),
  ];

  const rows = await db
    .select({
      unitId: unitsTable.id,
      unitLabel: unitsTable.label,
      rentCents: unitsTable.rentCents,
      bedrooms: unitsTable.bedrooms,
      bathrooms: unitsTable.bathrooms,
      squareFeet: unitsTable.squareFeet,
      buildingId: unitsTable.buildingId,
      buildingName: buildingsTable.name,
      buildingAddress: buildingsTable.address,
      opsStatus: unitReadinessTable.opsStatus,
      leasingStatus: unitReadinessTable.leasingStatus,
      blockingCount: unitReadinessTable.blockingCount,
      blockingSummary: unitReadinessTable.blockingSummary,
      readyAt: unitReadinessTable.readyAt,
      renovationRecordId: unitReadinessTable.currentRenovationRecordId,
    })
    .from(unitReadinessTable)
    .innerJoin(unitsTable, eq(unitReadinessTable.unitId, unitsTable.id))
    .innerJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
    .where(and(...conditions))
    .orderBy(unitReadinessTable.readyAt);

  return rows;
}

module.exports = { onUnitReadyForLeasing, listUnitsReadyForLeasing };
