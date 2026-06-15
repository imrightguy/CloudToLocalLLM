// ─── Departure / Arrival Photos Routes ───
// Authenticated CRUD for move-out / move-in photos. Mounted at /api/departure-photos.

const express = require('express');

const router = express.Router();
const departurePhotosController = require('../controllers/departure-photos.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { departurePhotoSchemas } = require('../config/validation-schemas');

router.get(
  '/',
  authenticateToken,
  validate(departurePhotoSchemas.list),
  asyncHandler(departurePhotosController.list),
);

router.post(
  '/',
  authenticateToken,
  validate(departurePhotoSchemas.create),
  asyncHandler(departurePhotosController.create),
);

router.delete(
  '/:id',
  authenticateToken,
  validate(departurePhotoSchemas.idParam),
  asyncHandler(departurePhotosController.remove),
);

module.exports = router;
