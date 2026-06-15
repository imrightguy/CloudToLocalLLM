const express = require('express');

const router = express.Router();
const maintenanceController = require('../controllers/maintenance.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { maintenanceSchemas } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/maintenance/command-center:
 *   get:
 *     tags: [Maintenance]
 *     summary: Get the maintenance command center
 *     description: Returns a read-only cross-property command center combining backlog, capacity, and tenant-message status.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: buildingId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Optional building filter for a single property view.
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 50
 *           default: 12
 *         description: Number of backlog items to return.
 *     responses:
 *       200:
 *         description: Maintenance command center payload
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
 *                         summary:
 *                           type: object
 *                           properties:
 *                             propertyCount:
 *                               type: integer
 *                             renovationCount:
 *                               type: integer
 *                             blockedCount:
 *                               type: integer
 *                             readyCount:
 *                               type: integer
 *                             overdueTaskCount:
 *                               type: integer
 *                             dueSoonTaskCount:
 *                               type: integer
 *                             openOrderCount:
 *                               type: integer
 *                             pendingIntakeCount:
 *                               type: integer
 *                             dispatchableEmployeeCount:
 *                               type: integer
 *                             tenantMessageSentCount:
 *                               type: integer
 *                             tenantMessageFailedCount:
 *                               type: integer
 *                             tenantMessagePendingCount:
 *                               type: integer
 *                         properties:
 *                           type: array
 *                         backlog:
 *                           type: array
 *                         tenantMessages:
 *                           type: array
 *                         reviewQueue:
 *                           type: object
 *                           properties:
 *                             summary:
 *                               type: object
 *                             recommendations:
 *                               type: array
 *                             asOf:
 *                               type: string
 *                               format: date-time
 *                         asOf:
 *                           type: string
 *                           format: date-time
 */
router.get('/command-center', authenticateToken, validate(maintenanceSchemas.commandCenter), asyncHandler(maintenanceController.getCommandCenter));

/**
 * @swagger
 * /api/maintenance/tickets:
 *   get:
 *     tags: [Maintenance]
 *     summary: List maintenance tickets
 *     description: Returns a paginated list of maintenance tickets with optional filters.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *       - in: query
 *         name: status
 *         schema: { type: string, enum: [ouvert, en_cours, resolu] }
 *       - in: query
 *         name: urgency
 *         schema: { type: string, enum: [basse, moyenne, haute, urgence] }
 *       - in: query
 *         name: buildingId
 *         schema: { type: string, format: uuid }
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *     responses:
 *       200:
 *         description: List of tickets
 *   post:
 *     tags: [Maintenance]
 *     summary: Create a maintenance ticket
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [title]
 *             properties:
 *               title: { type: string }
 *               description: { type: string }
 *               urgency: { type: string, enum: [basse, moyenne, haute, urgence] }
 *               status: { type: string, enum: [ouvert, en_cours, resolu] }
 *               callerPhone: { type: string }
 *               unitId: { type: string, format: uuid }
 *               buildingId: { type: string, format: uuid }
 *     responses:
 *       201:
 *         description: Ticket created
 */
router.get('/tickets', authenticateToken, validate(maintenanceSchemas.listTickets), asyncHandler(maintenanceController.getTickets));
router.post('/tickets', authenticateToken, validate(maintenanceSchemas.createTicket), asyncHandler(maintenanceController.createTicket));

/**
 * @swagger
 * /api/maintenance/webhook/vapi:
 *   post:
 *     tags: [Maintenance]
 *     summary: Vapi Voice AI inbound webhook
 *     description: >
 *       Receives a call/text event from the Vapi Voice AI agent and opens a maintenance ticket.
 *       Public endpoint protected by an optional X-Vapi-Secret header.
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *     responses:
 *       201:
 *         description: Ticket created from Vapi event
 *       200:
 *         description: Ticket already existed for this call
 */
router.post('/webhook/vapi', validate(maintenanceSchemas.vapiWebhook), asyncHandler(maintenanceController.receiveVapiWebhook));

/**
 * @swagger
 * /api/maintenance/tickets/{id}:
 *   get:
 *     tags: [Maintenance]
 *     summary: Get a maintenance ticket
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       200:
 *         description: Ticket details
 *       404:
 *         description: Ticket not found
 *   put:
 *     tags: [Maintenance]
 *     summary: Update a maintenance ticket
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               status: { type: string, enum: [ouvert, en_cours, resolu] }
 *               urgency: { type: string, enum: [basse, moyenne, haute, urgence] }
 *     responses:
 *       200:
 *         description: Ticket updated
 *       404:
 *         description: Ticket not found
 */
/**
 * @swagger
 * /api/maintenance/tickets/open-count-by-building:
 *   get:
 *     tags: [Maintenance]
 *     summary: Open ticket counts grouped by building
 *     description: >
 *       Returns the number of open tickets ('ouvert' or 'en_cours') per building,
 *       with the building name and a per-urgency breakdown. Powers the
 *       "Tickets par bâtiment" dashboard section.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Per-building open ticket breakdown
 */
// Doit précéder '/tickets/:id', sinon ':id' capture 'open-count-by-building'.
router.get('/tickets/open-count-by-building', authenticateToken, asyncHandler(maintenanceController.getOpenCountByBuilding));

router.get('/tickets/:id', authenticateToken, validate(maintenanceSchemas.ticketId), asyncHandler(maintenanceController.getTicketById));
router.put('/tickets/:id', authenticateToken, validate(maintenanceSchemas.updateTicket), asyncHandler(maintenanceController.updateTicket));

module.exports = router;
