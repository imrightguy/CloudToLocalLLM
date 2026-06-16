const { listUnitsReadyForLeasing } = require("../services/leasing-readiness.service");
const { successResponse, errorResponse, asyncHandler } = require("../utils/apiResponse");
const logger = require("../utils/logger");

/**
 * GET /api/leasing-readiness/units
 * List all units ready for leasing, optionally filtered by building.
 */
const getReadyUnits = async (req, res) => {
  try {
    const { buildingId } = req.query;
    const units = await listUnitsReadyForLeasing(buildingId || null);
    return successResponse(res, units, `${units.length} unité(s) prête(s) à louer`);
  } catch (err) {
    logger.error("Error listing ready units", { error: err.message });
    return errorResponse(res, 500, "READY_UNITS_FETCH_FAILED", "Erreur lors de la récupération des unités prêtes");
  }
};

module.exports = { getReadyUnits };
