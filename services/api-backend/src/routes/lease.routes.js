const express = require('express');

const router = express.Router();
const leaseController = require('../controllers/lease.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

router.get('/', authenticateToken, asyncHandler(leaseController.getLeases));
router.post('/', authenticateToken, asyncHandler(leaseController.createLease));
router.get('/building/:id', authenticateToken, asyncHandler(leaseController.getLeasesByBuilding));
router.get('/unit/:id', authenticateToken, asyncHandler(leaseController.getLeasesByUnit));
router.get('/:id', authenticateToken, asyncHandler(leaseController.getLeaseById));
router.patch('/:id', authenticateToken, asyncHandler(leaseController.updateLease));
router.delete('/:id', authenticateToken, asyncHandler(leaseController.deleteLease));
router.patch('/:id/status', authenticateToken, asyncHandler(leaseController.updateLeaseStatus));
router.patch('/:id/sign', authenticateToken, asyncHandler(leaseController.signLease));

module.exports = router;
