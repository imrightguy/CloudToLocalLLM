const express = require('express');
const router = express.Router();
const visitController = require('../controllers/visit.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

router.get('/', authenticateToken, asyncHandler(visitController.getVisits));
router.post('/', authenticateToken, asyncHandler(visitController.createVisit));
router.get('/:id', authenticateToken, asyncHandler(visitController.getVisitById));
router.put('/:id', authenticateToken, asyncHandler(visitController.updateVisit));
router.delete('/:id', authenticateToken, asyncHandler(visitController.deleteVisit));
router.patch('/:id/status', authenticateToken, asyncHandler(visitController.updateVisitStatus));

module.exports = router;
