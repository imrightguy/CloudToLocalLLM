const express = require('express');
const router = express.Router();
const buildingController = require('../controllers/building.controller');
const { asyncHandler } = require('../utils/apiResponse');

// Building routes
router.get('/', asyncHandler(buildingController.getBuildings));
router.post('/', asyncHandler(buildingController.createBuilding));
router.get('/:id', asyncHandler(buildingController.getBuildingById));
router.put('/:id', asyncHandler(buildingController.updateBuilding));
router.delete('/:id', asyncHandler(buildingController.deleteBuilding));

// Unit routes
router.get('/units', asyncHandler(buildingController.getUnits));
router.post('/units', asyncHandler(buildingController.createUnit));
router.get('/units/:id', asyncHandler(buildingController.getUnitById));
router.put('/units/:id', asyncHandler(buildingController.updateUnit));
router.delete('/units/:id', asyncHandler(buildingController.deleteUnit));

module.exports = router;