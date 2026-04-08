const express = require('express');
const router = express.Router();
const scheduleController = require('../controllers/schedule.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

router.get('/', authenticateToken, asyncHandler(scheduleController.getSchedules));
router.post('/', authenticateToken, asyncHandler(scheduleController.createSchedule));
router.get('/:id', authenticateToken, asyncHandler(scheduleController.getScheduleById));
router.put('/:id', authenticateToken, asyncHandler(scheduleController.updateSchedule));
router.delete('/:id', authenticateToken, asyncHandler(scheduleController.deleteSchedule));
router.get('/employee/:employeeId/availability', authenticateToken, asyncHandler((req, res) => {
  return scheduleController.getEmployeeAvailability(req, res, req.params.employeeId, req.query.date);
}));

module.exports = router;
