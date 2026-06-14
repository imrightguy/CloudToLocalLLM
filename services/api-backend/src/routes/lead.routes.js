const express = require('express');

const router = express.Router();
const leadController = require('../controllers/lead.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { leadSchemas, uuidParam } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/leads/webhook/marketplace:
 *   post:
 *     tags: [Leads]
 *     summary: Marketplace inbound webhook
 *     description: >
 *       Receives an inbound message from Kijiji / Facebook Marketplace, stores it as a lead,
 *       and notifies Hermes for qualification. Public endpoint protected by an optional
 *       X-Marketplace-Secret header.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name: { type: string }
 *               email: { type: string }
 *               phone: { type: string }
 *               source: { type: string, example: kijiji }
 *               message: { type: string }
 *               listingId: { type: string }
 *     responses:
 *       201:
 *         description: Lead ingested
 *       401:
 *         description: Invalid webhook secret
 */

/**
 * @swagger
 * /api/leads:
 *   get:
 *     tags: [Leads]
 *     summary: List all leads
 *     description: Returns a paginated list of leads with optional filtering.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum:
 *             - new
 *             - contacted
 *             - interested
 *             - viewing_scheduled
 *             - application_submitted
 *             - approved
 *             - rejected
 *             - leased
 *             - inactive
 *         description: Filter by lead status
 *       - in: query
 *         name: buildingId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by building
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *         description: Search by name, email, or phone
 *     responses:
 *       200:
 *         description: List of leads
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       type: array
 *                       items:
 *                         $ref: '#/components/schemas/Lead'
 *                     meta:
 *                       $ref: '#/components/schemas/PaginationMeta'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/webhook/marketplace', validate(leadSchemas.marketplaceWebhook), asyncHandler(leadController.receiveMarketplaceWebhook));

router.get('/', authenticateToken, asyncHandler(leadController.getLeads));

/**
 * @swagger
 * /api/leads:
 *   post:
 *     tags: [Leads]
 *     summary: Create a lead
 *     description: Create a new lead in the pipeline.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - firstName
 *               - lastName
 *             properties:
 *               firstName:
 *                 type: string
 *                 example: Pierre
 *               lastName:
 *                 type: string
 *                 example: Martin
 *               email:
 *                 type: string
 *                 format: email
 *                 example: pierre@email.com
 *               phone:
 *                 type: string
 *                 example: "+1514-555-0300"
 *               source:
 *                 type: string
 *                 example: facebook
 *               buildingId:
 *                 type: string
 *                 format: uuid
 *               unitId:
 *                 type: string
 *                 format: uuid
 *               notes:
 *                 type: string
 *     responses:
 *       201:
 *         description: Lead created
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lead'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/', authenticateToken, validate(leadSchemas.create), asyncHandler(leadController.createLead));

/**
 * @swagger
 * /api/leads/{id}:
 *   get:
 *     tags: [Leads]
 *     summary: Get lead by ID
 *     description: Returns a single lead with full details and activity history.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Lead details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lead'
 *       404:
 *         description: Lead not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/:id', authenticateToken, validate(uuidParam), asyncHandler(leadController.getLeadById));

/**
 * @swagger
 * /api/leads/{id}:
 *   put:
 *     tags: [Leads]
 *     summary: Update a lead
 *     description: Update a lead's information.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *               email:
 *                 type: string
 *                 format: email
 *               phone:
 *                 type: string
 *               source:
 *                 type: string
 *               buildingId:
 *                 type: string
 *                 format: uuid
 *               unitId:
 *                 type: string
 *                 format: uuid
 *               notes:
 *                 type: string
 *     responses:
 *       200:
 *         description: Lead updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lead'
 *       404:
 *         description: Lead not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.put('/:id', authenticateToken, validate(leadSchemas.update), asyncHandler(leadController.updateLead));

/**
 * @swagger
 * /api/leads/{id}:
 *   delete:
 *     tags: [Leads]
 *     summary: Delete a lead
 *     description: Delete a lead from the pipeline.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Lead deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Lead not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/:id', authenticateToken, validate(uuidParam), asyncHandler(leadController.deleteLead));

/**
 * @swagger
 * /api/leads/{id}/status:
 *   patch:
 *     tags: [Leads]
 *     summary: Update lead status
 *     description: Move a lead to a new stage in the pipeline.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 enum:
 *                   - new
 *                   - contacted
 *                   - interested
 *                   - viewing_scheduled
 *                   - application_submitted
 *                   - approved
 *                   - rejected
 *                   - leased
 *                   - inactive
 *     responses:
 *       200:
 *         description: Lead status updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lead'
 *       400:
 *         description: Invalid status transition
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.patch('/:id/status', authenticateToken, validate(leadSchemas.updateStatus), asyncHandler(leadController.updateLeadStatus));

/**
 * @swagger
 * /api/leads/{id}/notify-hermes:
 *   post:
 *     tags: [Leads]
 *     summary: Trigger Hermes qualification
 *     description: Sends an outbound notification to Hermes asking it to qualify the lead.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Hermes notification result
 *       404:
 *         description: Lead not found
 */
router.post('/:id/notify-hermes', authenticateToken, validate(uuidParam), asyncHandler(leadController.notifyHermesForLead));

/**
 * @swagger
 * /api/leads/bulk:
 *   post:
 *     tags: [Leads]
 *     summary: Bulk update leads
 *     description: Update multiple leads at once (e.g., reassign, change status).
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - leadIds
 *               - updates
 *             properties:
 *               leadIds:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uuid
 *                 example: ["uuid-1", "uuid-2"]
 *               updates:
 *                 type: object
 *                 properties:
 *                   status:
 *                     type: string
 *                     enum:
 *                       - new
 *                       - contacted
 *                       - interested
 *                       - viewing_scheduled
 *                       - application_submitted
 *                       - approved
 *                       - rejected
 *                       - leased
 *                       - inactive
 *                   buildingId:
 *                     type: string
 *                     format: uuid
 *                   employeeId:
 *                     type: string
 *                     format: uuid
 *     responses:
 *       200:
 *         description: Bulk update applied
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       type: object
 *                       properties:
 *                         updatedCount: { type: integer }
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/bulk', authenticateToken, validate(leadSchemas.bulkUpdate), asyncHandler(leadController.bulkUpdateLeads));

module.exports = router;
