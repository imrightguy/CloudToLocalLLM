const express = require('express');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { tenantChecklistSchemas } = require('../config/validation-schemas');
const controller = require('../controllers/tenant-checklist.controller');

const router = express.Router();

router.post('/start', authenticateToken, validate(tenantChecklistSchemas.start), asyncHandler(controller.startChecklistSession));
router.post('/:id/resume', authenticateToken, validate(tenantChecklistSchemas.resume), asyncHandler(controller.resumeChecklistSession));
router.post('/:id/pause', authenticateToken, validate(tenantChecklistSchemas.pause), asyncHandler(controller.pauseChecklistSession));
router.post('/:id/submit', authenticateToken, validate(tenantChecklistSchemas.submit), asyncHandler(controller.submitChecklistSession));
router.get('/:id/summary', authenticateToken, validate(tenantChecklistSchemas.summary), asyncHandler(controller.getChecklistSessionSummary));
router.get('/:id/manager-summary', authenticateToken, validate(tenantChecklistSchemas.summary), asyncHandler(controller.getManagerChecklistSessionSummary));

module.exports = router;
