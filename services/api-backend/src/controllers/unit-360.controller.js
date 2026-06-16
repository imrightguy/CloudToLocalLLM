const { eq, and, desc } = require("drizzle-orm");
const { db } = require("../database/connection");
const {
  unitsTable,
  buildingsTable,
  leasesTable,
  maintenanceTicketsTable,
  communicationLogsTable,
  renovationsTable,
  unitReadinessTable,
} = require("../database/schema");
const { successResponse, errorResponse } = require("../utils/apiResponse");
const logger = require("../utils/logger");

/**
 * GET /api/units/:id/360
 * Vue 360° d'une unité : bail actif, maintenance, communications, rénovation.
 */
const getUnit360 = async (req, res) => {
  try {
    const { id } = req.params;

    // 1. Unité + bâtiment
    const [unit] = await db
      .select({
        id: unitsTable.id,
        label: unitsTable.label,
        rentCents: unitsTable.rentCents,
        status: unitsTable.status,
        bedrooms: unitsTable.bedrooms,
        bathrooms: unitsTable.bathrooms,
        squareFeet: unitsTable.squareFeet,
        description: unitsTable.description,
        amenities: unitsTable.amenities,
        tenantName: unitsTable.tenantName,
        tenantPhone: unitsTable.tenantPhone,
        tenantLeaseEnd: unitsTable.tenantLeaseEnd,
        buildingId: unitsTable.buildingId,
        buildingName: buildingsTable.name,
        buildingAddress: buildingsTable.address,
        buildingCity: buildingsTable.city,
      })
      .from(unitsTable)
      .innerJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
      .where(and(eq(unitsTable.id, id), eq(unitsTable.isActive, true)))
      .limit(1);

    if (!unit) {
      return errorResponse(res, 404, "UNIT_NOT_FOUND", "Unité introuvable");
    }

    // 2. Bail actif
    const [activeLease] = await db
      .select()
      .from(leasesTable)
      .where(
        and(
          eq(leasesTable.unitId, id),
          eq(leasesTable.isActive, true),
        )
      )
      .orderBy(desc(leasesTable.startDate))
      .limit(1);

    // 3. Tickets maintenance (ouverts + récents)
    const maintenanceTickets = await db
      .select()
      .from(maintenanceTicketsTable)
      .where(
        and(
          eq(maintenanceTicketsTable.unitId, id),
          eq(maintenanceTicketsTable.isActive, true),
        )
      )
      .orderBy(desc(maintenanceTicketsTable.createdAt))
      .limit(20);

    // 4. Historique communications (dernières 20)
    const communications = await db
      .select()
      .from(communicationLogsTable)
      .where(eq(communicationLogsTable.unitId, id))
      .orderBy(desc(communicationLogsTable.createdAt))
      .limit(20);

    // 5. État rénovation
    const [renovation] = await db
      .select()
      .from(renovationsTable)
      .where(
        and(
          eq(renovationsTable.unitId, id),
          eq(renovationsTable.isActive, true),
        )
      )
      .orderBy(desc(renovationsTable.createdAt))
      .limit(1);

    const [readiness] = await db
      .select()
      .from(unitReadinessTable)
      .where(eq(unitReadinessTable.unitId, id))
      .limit(1);

    const result = {
      unit,
      activeLease: activeLease || null,
      maintenanceTickets,
      communications,
      renovation: renovation || null,
      readiness: readiness || null,
    };

    return successResponse(res, result, "Vue 360° chargée");
  } catch (err) {
    logger.error("Error fetching unit 360", { error: err.message, unitId: req.params.id });
    return errorResponse(res, 500, "UNIT_360_FETCH_FAILED", "Erreur lors du chargement de la vue 360°");
  }
};

module.exports = { getUnit360 };
