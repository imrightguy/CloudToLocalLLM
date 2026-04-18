const express = require('express');

const router = express.Router();
const tenantConfirmationController = require('../controllers/tenant-confirmation.controller');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { tenantConfirmationSchemas } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/confirm/{token}:
 *   get:
 *     tags: [Tenant Confirmation]
 *     summary: Get confirmation page
 *     description: >
 *       Renders an HTML confirmation page for a tenant to review and
 *       confirm/decline their lease. No authentication required —
 *       accessed via unique SMS link token.
 *     parameters:
 *       - in: path
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *         description: Unique confirmation token from SMS link
 *     responses:
 *       200:
 *         description: HTML confirmation page
 *         content:
 *           text/html:
 *             schema:
 *               type: string
 *       404:
 *         description: Invalid or expired token
 */
router.get('/:token', validate(tenantConfirmationSchemas.getPage), asyncHandler(tenantConfirmationController.getConfirmationPage));

/**
 * @swagger
 * /api/confirm/{token}:
 *   post:
 *     tags: [Tenant Confirmation]
 *     summary: Submit confirmation
 *     description: Processes the tenant's confirm or decline action on their lease.
 *     parameters:
 *       - in: path
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *         description: Unique confirmation token from SMS link
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - action
 *             properties:
 *               action:
 *                 type: string
 *                 enum: [confirm, decline]
 *                 description: Tenant's decision
 *     responses:
 *       200:
 *         description: Confirmation processed
 *         content:
 *           text/html:
 *             schema:
 *               type: string
 *       400:
 *         description: Invalid action
 *       404:
 *         description: Invalid or expired token
 */
router.post('/:token', validate(tenantConfirmationSchemas.submit), asyncHandler(tenantConfirmationController.submitConfirmation));

module.exports = router;
