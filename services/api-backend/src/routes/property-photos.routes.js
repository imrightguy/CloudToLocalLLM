// ─── Property Photos Routes ───

const express = require('express');
const router = express.Router();
const propertyPhotosController = require('../controllers/property-photos.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const { parsePropertyPhotoUpload } = require('../middleware/photo-upload.middleware');

router.post('/upload', authenticateToken, parsePropertyPhotoUpload, asyncHandler(propertyPhotosController.upload));
router.get('/building/:buildingId', authenticateToken, asyncHandler(propertyPhotosController.getByBuilding));
router.get('/unit/:unitId', authenticateToken, asyncHandler(propertyPhotosController.getByUnit));
router.delete('/:id', authenticateToken, asyncHandler(propertyPhotosController.delete));
router.patch('/:id', authenticateToken, asyncHandler(propertyPhotosController.update));

module.exports = router;
