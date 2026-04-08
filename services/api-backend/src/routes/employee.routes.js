const express = require('express');
const router = express.Router();
const employeeController = require('../controllers/employee.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

router.get('/', authenticateToken, asyncHandler(employeeController.getEmployees));
router.post('/', authenticateToken, asyncHandler(employeeController.createEmployee));
router.get('/:id', authenticateToken, asyncHandler(employeeController.getEmployeeById));
router.put('/:id', authenticateToken, asyncHandler(employeeController.updateEmployee));
router.delete('/:id', authenticateToken, asyncHandler(employeeController.deleteEmployee));

// Assignments
router.post('/:id/assign', authenticateToken, asyncHandler((req, res) => {
  return employeeController.assignEmployee(req, res, req.params.id, req.body.buildingId, req.body.role);
}));
router.delete('/:id/assign/:assignmentId', authenticateToken, asyncHandler((req, res) => {
  return employeeController.removeAssignment(req, res, req.params.assignmentId);
}));
router.get('/building/:buildingId', authenticateToken, asyncHandler((req, res) => {
  return employeeController.getBuildingEmployees(req, res, req.params.buildingId);
}));

module.exports = router;
