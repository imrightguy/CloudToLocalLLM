const express = require('express');
const router = express.Router();
const buildingController = require('../controllers/building.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

// Building routes
router.get('/', authenticateToken, asyncHandler(buildingController.getBuildings));
router.post('/', authenticateToken, asyncHandler(buildingController.createBuilding));
router.get('/:id', authenticateToken, asyncHandler(buildingController.getBuildingById));
router.put('/:id', authenticateToken, asyncHandler(buildingController.updateBuilding));
router.delete('/:id', authenticateToken, asyncHandler(buildingController.deleteBuilding));

// Unit routes — MUST be before /:id to avoid collision
router.get('/units', authenticateToken, asyncHandler(buildingController.getUnits));
router.post('/units', authenticateToken, asyncHandler(buildingController.createUnit));
router.get('/units/:id', authenticateToken, asyncHandler(buildingController.getUnitById));
router.put('/units/:id', authenticateToken, asyncHandler(buildingController.updateUnit));
router.delete('/units/:id', authenticateToken, asyncHandler(buildingController.deleteUnit));

module.exports = router;
