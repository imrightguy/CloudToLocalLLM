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
// Public (no auth): photo files must be loadable by <img>/Image.network and
// referenceable from public listings ("annonces"). Access is by unguessable UUID.
router.get('/:photoId/file', validate(photoRecordSchemas.download), asyncHandler(controller.downloadPropertyPhotoFile));
router.patch('/:photoId', authenticateToken, validate(photoRecordSchemas.update), asyncHandler(controller.updatePropertyPhoto));
router.delete('/:photoId', authenticateToken, validate(photoRecordSchemas.remove), asyncHandler(controller.deletePropertyPhoto));

module.exports = router;
