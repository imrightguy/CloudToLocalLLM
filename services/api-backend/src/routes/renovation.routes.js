const express = require('express');

const router = express.Router();
const renovationController = require('../controllers/renovation.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { uuidParam } = require('../config/validation-schemas');

router.get('/', authenticateToken, asyncHandler(renovationController.getRenovationRecords));
router.post('/', authenticateToken, asyncHandler(renovationController.createRenovationRecord));
router.get('/dashboard', authenticateToken, asyncHandler(renovationController.getDashboard));
router.get('/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.getRenovationRecordById));
router.patch('/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.updateRenovationRecord));
router.delete('/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.deleteRenovationRecord));

router.get('/:id([0-9a-fA-F-]{36})/tasks', authenticateToken, validate(uuidParam), asyncHandler(renovationController.getRenovationTasks));
router.post('/:id([0-9a-fA-F-]{36})/tasks', authenticateToken, validate(uuidParam), (req, _res, next) => { req.body = { ...(req.body || {}), renovationRecordId: req.params.id }; next(); }, asyncHandler(renovationController.createRenovationTask));
router.patch('/tasks/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.updateRenovationTask));
router.delete('/tasks/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.deleteRenovationTask));

router.get('/:id([0-9a-fA-F-]{36})/orders', authenticateToken, validate(uuidParam), asyncHandler(renovationController.getRenovationOrders));
router.post('/:id([0-9a-fA-F-]{36})/orders', authenticateToken, validate(uuidParam), (req, _res, next) => { req.body = { ...(req.body || {}), renovationRecordId: req.params.id }; next(); }, asyncHandler(renovationController.createRenovationOrder));
router.patch('/orders/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.updateRenovationOrder));
router.delete('/orders/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.deleteRenovationOrder));
router.post('/orders/:id([0-9a-fA-F-]{36})/receiving', authenticateToken, validate(uuidParam), asyncHandler(renovationController.createReceivingEvent));
router.get('/orders/:id([0-9a-fA-F-]{36})/receiving', authenticateToken, validate(uuidParam), asyncHandler(renovationController.getRenovationReceivingEvents));

router.get('/:id([0-9a-fA-F-]{36})/surplus', authenticateToken, validate(uuidParam), asyncHandler(renovationController.getRenovationSurplusItems));
router.post('/:id([0-9a-fA-F-]{36})/surplus', authenticateToken, validate(uuidParam), (req, _res, next) => { req.body = { ...(req.body || {}), renovationRecordId: req.params.id }; next(); }, asyncHandler(renovationController.createRenovationSurplusItem));
router.patch('/surplus/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.updateRenovationSurplusItem));
router.delete('/surplus/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.deleteRenovationSurplusItem));

router.get('/:id([0-9a-fA-F-]{36})/intake', authenticateToken, validate(uuidParam), asyncHandler(renovationController.getRenovationWorkerIntakeRecords));
router.post('/:id([0-9a-fA-F-]{36})/intake', authenticateToken, validate(uuidParam), (req, _res, next) => { req.body = { ...(req.body || {}), renovationRecordId: req.params.id }; next(); }, asyncHandler(renovationController.createRenovationWorkerIntakeRecord));
router.patch('/intake/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.updateRenovationWorkerIntakeRecord));
router.delete('/intake/:id([0-9a-fA-F-]{36})', authenticateToken, validate(uuidParam), asyncHandler(renovationController.deleteRenovationWorkerIntakeRecord));

module.exports = router;
