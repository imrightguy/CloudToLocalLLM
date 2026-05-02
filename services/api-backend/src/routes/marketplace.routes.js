const express = require('express');

const router = express.Router();
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { marketplaceSchemas } = require('../config/validation-schemas');
const {
  getConversationThreads,
  getLeadTimeline,
  recordCommunicationActivity,
  recordMarketplaceVisit,
} = require('../services/communication-thread.service');

const listInbox = async (req, res) => {
  const result = await getConversationThreads({
    ...req.query,
    includeMessages: false,
  });

  return res.json({ success: true, data: result.threads, metadata: result.pagination });
};

const listTimeline = async (req, res) => {
  const result = await getLeadTimeline(req.params.leadId, {
    ...req.query,
    includeMessages: true,
  });

  return res.json({
    success: true,
    data: result,
    metadata: result
      ? {
        leadId: result.leadId,
        coordinationState: result.coordinationState,
        messageCount: result.messageCount,
        lastMessageAt: result.lastMessageAt,
      }
      : {
        leadId: req.params.leadId,
        coordinationState: null,
        messageCount: 0,
        lastMessageAt: null,
      },
  });
};

const postMessage = async (req, res) => {
  const result = await recordCommunicationActivity({
    ...req.body,
    leadId: req.params.leadId,
  });

  return res.status(result.statusCode).json(result.body);
};

const postVisit = async (req, res) => {
  const result = await recordMarketplaceVisit(req.params.leadId, req.body);

  return res.status(result.statusCode).json(result.body);
};

/**
 * @swagger
 * /api/marketplace/inbox:
 *   get:
 *     tags: [Marketplace]
 *     summary: List marketplace inbox threads
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: search
 *         schema: { type: string }
 *       - in: query
 *         name: stage
 *         schema:
 *           type: string
 *           enum:
 *             - nouveau
 *             - contacte
 *             - qualifie
 *             - visitePlanifiee
 *             - visite_planifiee
 *             - offreEnvoyee
 *             - negociation
 *             - bailSigne
 *             - signe
 *             - visite_completee
 *             - interesse
 *             - inactif
 *       - in: query
 *         name: assignedEmployeeId
 *         schema: { type: string, format: uuid }
 *       - in: query
 *         name: source
 *         schema: { type: string }
 *       - in: query
 *         name: page
 *         schema: { type: integer, default: 1 }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 20 }
 *     responses:
 *       200:
 *         description: Inbox threads
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
 *                         $ref: '#/components/schemas/CommunicationThread'
 *                     metadata:
 *                       $ref: '#/components/schemas/PaginationMeta'
 */
router.get('/inbox', authenticateToken, validate(marketplaceSchemas.inbox), asyncHandler(listInbox));

/**
 * @swagger
 * /api/marketplace/leads/{leadId}/timeline:
 *   get:
 *     tags: [Marketplace]
 *     summary: Get a lead timeline
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: leadId
 *         required: true
 *         schema: { type: string, format: uuid }
 *       - in: query
 *         name: limit
 *         schema: { type: integer, default: 50 }
 *       - in: query
 *         name: hoursAgo
 *         schema: { type: integer, default: 168 }
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [email, phone, sms, fb_messenger]
 *     responses:
 *       200:
 *         description: Lead timeline
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       allOf:
 *                         - $ref: '#/components/schemas/CommunicationThread'
 *                         - nullable: true
 */
router.get('/leads/:leadId/timeline', authenticateToken, validate(marketplaceSchemas.timeline), asyncHandler(listTimeline));

/**
 * @swagger
 * /api/marketplace/leads/{leadId}/messages:
 *   post:
 *     tags: [Marketplace]
 *     summary: Log a marketplace message for a lead
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: leadId
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [type, direction]
 *             properties:
 *               employeeId:
 *                 type: string
 *                 format: uuid
 *                 nullable: true
 *               type:
 *                 type: string
 *                 enum: [email, phone, sms, fb_messenger]
 *               direction:
 *                 type: string
 *                 enum: [inbound, outbound]
 *               subject:
 *                 type: string
 *               content:
 *                 type: string
 *               body:
 *                 type: string
 *               attachments:
 *                 type: array
 *               status:
 *                 type: string
 *               metadata:
 *                 type: object
 *                 additionalProperties: true
 *     responses:
 *       201:
 *         description: Message logged
 *       400:
 *         description: Validation error
 */
router.post('/leads/:leadId/messages', authenticateToken, validate(marketplaceSchemas.leadMessage), asyncHandler(postMessage));

/**
 * @swagger
 * /api/marketplace/leads/{leadId}/visits:
 *   post:
 *     tags: [Marketplace]
 *     summary: Create a marketplace visit for a lead
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: leadId
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [unitId, employeeId, dateTime]
 *             properties:
 *               unitId:
 *                 type: string
 *                 format: uuid
 *               employeeId:
 *                 type: string
 *                 format: uuid
 *               dateTime:
 *                 type: string
 *                 format: date-time
 *               durationMinutes:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 1440
 *               status:
 *                 type: string
 *                 enum: [scheduled, confirmed, in_progress, completed, cancelled, no_show]
 *               notes:
 *                 type: string
 *     responses:
 *       201:
 *         description: Visit created
 *       400:
 *         description: Validation error
 *       409:
 *         description: Visit conflict or schedule conflict
 */
router.post('/leads/:leadId/visits', authenticateToken, validate(marketplaceSchemas.leadVisit), asyncHandler(postVisit));

module.exports = router;
