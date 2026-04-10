const express = require('express');

const router = express.Router();
const tenantConfirmationController = require('../controllers/tenant-confirmation.controller');
const { asyncHandler } = require('../utils/apiResponse');

// ─── Public tenant confirmation endpoints (no auth — tenants click from SMS) ───
// GET: renders HTML confirmation page
// POST: processes confirm/decline
router.get('/:token', asyncHandler(tenantConfirmationController.getConfirmationPage));
router.post('/:token', asyncHandler(tenantConfirmationController.submitConfirmation));

module.exports = router;
