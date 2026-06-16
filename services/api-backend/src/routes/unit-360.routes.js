const express = require("express");
const router = express.Router();
const { authenticateToken } = require("../auth/jwt.middleware");
const { asyncHandler } = require("../utils/apiResponse");
const controller = require("../controllers/unit-360.controller");

/**
 * GET /api/units/:id/360
 * Vue 360° d'une unité : bail actif, maintenance, communications, rénovation.
 */
router.get("/:id/360", authenticateToken, asyncHandler(controller.getUnit360));

module.exports = router;
