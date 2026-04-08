const express = require('express');
const router = express.Router();
const leadController = require('../controllers/lead.controller');
const { asyncHandler } = require('../utils/apiResponse');

// Lead routes
router.get('/', asyncHandler(leadController.getLeads));
router.post('/', asyncHandler(leadController.createLead));
router.get('/:id', asyncHandler(leadController.getLeadById));
router.put('/:id', asyncHandler(leadController.updateLead));
router.delete('/:id', asyncHandler(leadController.deleteLead));

// Lead status update
router.patch('/:id/status', asyncHandler(leadController.updateLeadStatus));

// Lead bulk operations
router.post('/bulk', asyncHandler(leadController.bulkUpdateLeads));

// Lead import/export
router.post('/import', asyncHandler(leadController.importLeads));
router.get('/export', asyncHandler(leadController.exportLeads));

module.exports = router;