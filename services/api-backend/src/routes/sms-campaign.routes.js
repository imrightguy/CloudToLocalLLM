const express = require('express');

const router = express.Router();
const smsCampaignController = require('../controllers/sms-campaign.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { smsCampaignSchemas, uuidParam } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/sms/templates:
 *   post:
 *     tags: [SMS Campaigns]
 *     summary: Create an SMS template
 *     description: Create a new reusable SMS template with variable placeholders.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - body
 *             properties:
 *               name:
 *                 type: string
 *                 example: "visit_reminder"
 *               body:
 *                 type: string
 *                 example: "Bonjour {{firstName}}, rappel de votre visite le {{date}} a {{time}}."
 *               category:
 *                 type: string
 *                 example: "visit"
 *     responses:
 *       201:
 *         description: Template created
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/SmsTemplate'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/templates', authenticateToken, validate(smsCampaignSchemas.createTemplate), asyncHandler(smsCampaignController.createTemplateHandler));

/**
 * @swagger
 * /api/sms/templates:
 *   get:
 *     tags: [SMS Campaigns]
 *     summary: List SMS templates
 *     description: Returns all SMS templates.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of templates
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
 *                         $ref: '#/components/schemas/SmsTemplate'
 */
router.get('/templates', authenticateToken, asyncHandler(smsCampaignController.getTemplatesHandler));

/**
 * @swagger
 * /api/sms/templates/preview:
 *   get:
 *     tags: [SMS Campaigns]
 *     summary: Preview a template
 *     description: Render a template with sample variable data to preview the message.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: templateId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: variables
 *         schema:
 *           type: string
 *         description: JSON string of variable values
 *         example: '{"firstName":"Pierre","date":"15 mai","time":"14h"}'
 *     responses:
 *       200:
 *         description: Rendered preview
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
 *                         rendered: { type: string }
 *                         characterCount: { type: integer }
 *                         segmentCount: { type: integer }
 */
router.get('/templates/preview', authenticateToken, asyncHandler(smsCampaignController.previewTemplateHandler));

/**
 * @swagger
 * /api/sms/templates/{id}:
 *   get:
 *     tags: [SMS Campaigns]
 *     summary: Get template by ID
 *     description: Returns a single SMS template.
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
 *         description: Template details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/SmsTemplate'
 *       404:
 *         description: Template not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/templates/:id', authenticateToken, asyncHandler(smsCampaignController.getTemplateByIdHandler));

/**
 * @swagger
 * /api/sms/templates/{id}:
 *   patch:
 *     tags: [SMS Campaigns]
 *     summary: Update an SMS template
 *     description: Update an existing SMS template.
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
 *               name:
 *                 type: string
 *               body:
 *                 type: string
 *               category:
 *                 type: string
 *               isActive:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Template updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/SmsTemplate'
 *       404:
 *         description: Template not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.patch('/templates/:id', authenticateToken, validate(smsCampaignSchemas.updateTemplate), asyncHandler(smsCampaignController.updateTemplateHandler));

/**
 * @swagger
 * /api/sms/templates/{id}:
 *   delete:
 *     tags: [SMS Campaigns]
 *     summary: Delete an SMS template
 *     description: Delete an SMS template.
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
 *         description: Template deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Template not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/templates/:id', authenticateToken, validate(uuidParam), asyncHandler(smsCampaignController.deleteTemplateHandler));

/**
 * @swagger
 * /api/sms/campaigns:
 *   post:
 *     tags: [SMS Campaigns]
 *     summary: Create an SMS campaign
 *     description: Create a new SMS campaign using a template and a list of recipients.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - templateId
 *               - recipientIds
 *             properties:
 *               name:
 *                 type: string
 *                 example: "May visit reminders"
 *               templateId:
 *                 type: string
 *                 format: uuid
 *               recipientIds:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uuid
 *                 description: Lead IDs to send to
 *               scheduledAt:
 *                 type: string
 *                 format: date-time
 *                 description: When to execute the campaign (optional, runs immediately if omitted)
 *     responses:
 *       201:
 *         description: Campaign created
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/SmsCampaign'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/campaigns', authenticateToken, validate(smsCampaignSchemas.createCampaign), asyncHandler(smsCampaignController.createCampaignHandler));

/**
 * @swagger
 * /api/sms/campaigns:
 *   get:
 *     tags: [SMS Campaigns]
 *     summary: List SMS campaigns
 *     description: Returns all SMS campaigns.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of campaigns
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
 *                         $ref: '#/components/schemas/SmsCampaign'
 */
router.get('/campaigns', authenticateToken, asyncHandler(smsCampaignController.getCampaignsHandler));

/**
 * @swagger
 * /api/sms/campaigns/{id}:
 *   get:
 *     tags: [SMS Campaigns]
 *     summary: Get campaign by ID
 *     description: Returns a single SMS campaign with execution stats.
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
 *         description: Campaign details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/SmsCampaign'
 *       404:
 *         description: Campaign not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/campaigns/:id', authenticateToken, asyncHandler(smsCampaignController.getCampaignByIdHandler));

/**
 * @swagger
 * /api/sms/campaigns/{id}:
 *   patch:
 *     tags: [SMS Campaigns]
 *     summary: Update an SMS campaign
 *     description: Update campaign details (name, recipients, schedule).
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
 *               name:
 *                 type: string
 *               recipientIds:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uuid
 *               scheduledAt:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       200:
 *         description: Campaign updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/SmsCampaign'
 *       404:
 *         description: Campaign not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.patch('/campaigns/:id', authenticateToken, validate(smsCampaignSchemas.updateCampaign), asyncHandler(smsCampaignController.updateCampaignHandler));

/**
 * @swagger
 * /api/sms/campaigns/{id}:
 *   delete:
 *     tags: [SMS Campaigns]
 *     summary: Delete an SMS campaign
 *     description: Delete a draft SMS campaign.
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
 *         description: Campaign deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Campaign not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/campaigns/:id', authenticateToken, validate(uuidParam), asyncHandler(smsCampaignController.deleteCampaignHandler));

/**
 * @swagger
 * /api/sms/campaigns/{id}/activate:
 *   post:
 *     tags: [SMS Campaigns]
 *     summary: Activate a campaign
 *     description: Activate a draft campaign so it can be executed.
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
 *         description: Campaign activated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/SmsCampaign'
 */
router.post('/campaigns/:id/activate', authenticateToken, asyncHandler(smsCampaignController.activateCampaignHandler));

/**
 * @swagger
 * /api/sms/campaigns/{id}/execute:
 *   post:
 *     tags: [SMS Campaigns]
 *     summary: Execute a campaign
 *     description: Immediately execute an active campaign (send all messages).
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
 *         description: Campaign execution started
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
 *                         campaignId: { type: string, format: uuid }
 *                         status: { type: string }
 *                         recipientCount: { type: integer }
 */
router.post('/campaigns/:id/execute', authenticateToken, asyncHandler(smsCampaignController.executeCampaignHandler));

module.exports = router;
