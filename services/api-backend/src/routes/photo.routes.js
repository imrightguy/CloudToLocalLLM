const express = require('express');

const router = express.Router({ mergeParams: true });
const controller = require('../controllers/photo.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { parsePropertyPhotoUpload } = require('../middleware/photo-upload.middleware');
const { photoRecordSchemas } = require('../config/validation-schemas');

router.get('/', authenticateToken, validate(photoRecordSchemas.list), asyncHandler(controller.listPropertyPhotos));
router.post('/', authenticateToken, validate(photoRecordSchemas.create), asyncHandler(controller.createPropertyPhoto));
router.post('/upload', authenticateToken, parsePropertyPhotoUpload, validate(photoRecordSchemas.upload), asyncHandler(controller.uploadPropertyPhoto));
router.get('/:photoId/file', authenticateToken, validate(photoRecordSchemas.download), asyncHandler(controller.downloadPropertyPhotoFile));

module.exports = router;
