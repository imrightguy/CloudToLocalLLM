// ─── Property Photos Routes ───

const express = require('express');
const router = express.Router();
const multer = require('multer');
const propertyPhotosController = require('../controllers/property-photos.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 1 },
  fileFilter: (_req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];
    cb(null, allowed.includes(file.mimetype));
  },
});

router.post('/upload', authenticateToken, upload.single('file'), asyncHandler(propertyPhotosController.upload));
router.get('/building/:buildingId', authenticateToken, asyncHandler(propertyPhotosController.getByBuilding));
router.get('/unit/:unitId', authenticateToken, asyncHandler(propertyPhotosController.getByUnit));
router.delete('/:id', authenticateToken, asyncHandler(propertyPhotosController.delete));
router.patch('/:id', authenticateToken, asyncHandler(propertyPhotosController.update));

module.exports = router;
