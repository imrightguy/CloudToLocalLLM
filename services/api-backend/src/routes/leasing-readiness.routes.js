const express = require("express");
const router = express.Router();
const { authenticateToken } = require("../auth/jwt.middleware");
const { asyncHandler } = require("../utils/apiResponse");
const controller = require("../controllers/leasing-readiness.controller");

/**
 * GET /api/leasing-readiness/units?buildingId=...
 * List all units ready for leasing.
 */
router.get("/units", authenticateToken, asyncHandler(controller.getReadyUnits));

module.exports = router;
