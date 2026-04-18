const express = require('express');

const router = express.Router();
const communicationController = require('../controllers/communication.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { communicationSchemas, uuidParam } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/communications:
 *   get:
 *     tags: [Communications]
 *     summary: List communications
 *     description: Returns a paginated list of communications.
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
 *         name: leadId
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [email, phone, sms, in_person, whatsapp]
 *     responses:
 *       200:
 *         description: List of communications
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
 *                         $ref: '#/components/schemas/Communication'
 *                     meta:
 *                       $ref: '#/components/schemas/PaginationMeta'
 */
router.get('/', authenticateToken, asyncHandler(communicationController.getCommunications));

/**
 * @swagger
 * /api/communications/activity:
 *   get:
 *     tags: [Communications]
 *     summary: Get activity feed
 *     description: Returns a chronological activity feed of recent communications across all leads.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *     responses:
 *       200:
 *         description: Activity feed
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
 *                         type: object
 *                         properties:
 *                           id: { type: string }
 *                           type: { type: string }
 *                           leadName: { type: string }
 *                           direction: { type: string }
 *                           subject: { type: string }
 *                           createdAt: { type: string, format: date-time }
 */
router.get('/activity', authenticateToken, asyncHandler(communicationController.getActivityFeed));

/**
 * @swagger
 * /api/communications:
 *   post:
 *     tags: [Communications]
 *     summary: Log a communication
 *     description: Log a new communication (call, email, SMS, etc.) for a lead.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - leadId
 *               - type
 *               - direction
 *             properties:
 *               leadId:
 *                 type: string
 *                 format: uuid
 *               type:
 *                 type: string
 *                 enum: [email, phone, sms, in_person, whatsapp]
 *               direction:
 *                 type: string
 *                 enum: [inbound, outbound]
 *               subject:
 *                 type: string
 *               content:
 *                 type: string
 *     responses:
 *       201:
 *         description: Communication logged
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Communication'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/', authenticateToken, validate(communicationSchemas.log), asyncHandler(communicationController.logCommunication));

/**
 * @swagger
 * /api/communications/logs:
 *   get:
 *     tags: [Communications]
 *     summary: List communication logs
 *     description: Returns a paginated list of detailed communication logs.
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
 *         name: leadId
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: List of communication logs
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
 *                         $ref: '#/components/schemas/Communication'
 *                     meta:
 *                       $ref: '#/components/schemas/PaginationMeta'
 */
router.get('/logs', authenticateToken, asyncHandler(communicationController.getCommunicationLogs));

/**
 * @swagger
 * /api/communications/logs/{id}:
 *   get:
 *     tags: [Communications]
 *     summary: Get communication log by ID
 *     description: Returns a single communication log entry.
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
 *         description: Communication log details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Communication'
 *       404:
 *         description: Log not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/logs/:id', authenticateToken, validate(uuidParam), asyncHandler(communicationController.getCommunicationLogById));

/**
 * @swagger
 * /api/communications/logs/{id}:
 *   put:
 *     tags: [Communications]
 *     summary: Update a communication log
 *     description: Update a communication log entry.
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
 *               subject:
 *                 type: string
 *               content:
 *                 type: string
 *               type:
 *                 type: string
 *                 enum: [email, phone, sms, in_person, whatsapp]
 *     responses:
 *       200:
 *         description: Communication log updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Communication'
 *       404:
 *         description: Log not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.put('/logs/:id', authenticateToken, validate(communicationSchemas.updateLog), asyncHandler(communicationController.updateCommunicationLog));

/**
 * @swagger
 * /api/communications/logs/{id}:
 *   delete:
 *     tags: [Communications]
 *     summary: Delete a communication log
 *     description: Delete a communication log entry.
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
 *         description: Communication log deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Log not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/logs/:id', authenticateToken, validate(uuidParam), asyncHandler(communicationController.deleteCommunicationLog));

module.exports = router;
