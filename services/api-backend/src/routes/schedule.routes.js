const express = require('express');
const router = express.Router();
const scheduleController = require('../controllers/schedule.controller');
const { asyncHandler } = require('../utils/apiResponse');

// Schedule routes
router.get('/', asyncHandler(scheduleController.getSchedules));
router.post('/', asyncHandler(scheduleController.createSchedule));
router.get('/:id', asyncHandler(scheduleController.getScheduleById));
router.put('/:id', asyncHandler(scheduleController.updateSchedule));
router.delete('/:id', asyncHandler(scheduleController.deleteSchedule));

// Schedule search
router.get('/search', asyncHandler(scheduleController.searchSchedules));

// Schedule bulk operations
router.post('/bulk', asyncHandler(scheduleController.bulkUpdateSchedules));

// Schedule availability
router.get('/availability', asyncHandler(scheduleController.checkAvailability));

// Schedule reminders
router.post('/:id/reminders', asyncHandler(scheduleController.createScheduleReminder));

// Recurring schedule exceptions
router.post('/:id/exceptions', asyncHandler(scheduleController.addScheduleException));

module.exports = router;