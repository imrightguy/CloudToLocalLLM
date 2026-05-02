const express = require('express');

const router = express.Router();
const controller = require('../controllers/observation-result.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { observationResultSchemas } = require('../config/validation-schemas');

router.get('/', authenticateToken, validate(observationResultSchemas.list), asyncHandler(controller.listObservationResults));
router.post('/import', authenticateToken, validate(observationResultSchemas.import), asyncHandler(controller.importObservationResults));
router.get('/:id', authenticateToken, validate(observationResultSchemas.detail), asyncHandler(controller.getObservationResultById));
router.patch('/:id/review', authenticateToken, validate(observationResultSchemas.review), asyncHandler(controller.reviewObservationResult));
router.patch('/:id/dismiss', authenticateToken, validate(observationResultSchemas.dismiss), asyncHandler(controller.dismissObservationResult));

module.exports = router;
