const express = require('express');
const router = express.Router();
const visitController = require('../controllers/visit.controller');
const { asyncHandler } = require('../utils/apiResponse');

// Visit routes
router.get('/', asyncHandler(visitController.getVisits));
router.post('/', asyncHandler(visitController.createVisit));
router.get('/:id', asyncHandler(visitController.getVisitById));
router.put('/:id', asyncHandler(visitController.updateVisit));
router.delete('/:id', asyncHandler(visitController.deleteVisit));

// Visit status update
router.patch('/:id/status', asyncHandler(visitController.updateVisitStatus));

// Visit bulk operations
router.post('/bulk', asyncHandler(visitController.bulkUpdateVisits));

// Visit availability
router.get('/availability', asyncHandler(visitController.checkAvailability));

// Visit reminders
router.post('/:id/reminders', asyncHandler(visitController.createVisitReminder));

module.exports = router;