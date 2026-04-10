const express = require('express');

const router = express.Router();
const leadController = require('../controllers/lead.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

router.get('/', authenticateToken, asyncHandler(leadController.getLeads));
router.post('/', authenticateToken, asyncHandler(leadController.createLead));
router.get('/:id', authenticateToken, asyncHandler(leadController.getLeadById));
router.put('/:id', authenticateToken, asyncHandler(leadController.updateLead));
router.delete('/:id', authenticateToken, asyncHandler(leadController.deleteLead));
router.patch('/:id/status', authenticateToken, asyncHandler(leadController.updateLeadStatus));
router.post('/bulk', authenticateToken, asyncHandler(leadController.bulkUpdateLeads));

module.exports = router;
