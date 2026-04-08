import express from 'express';
import { leadController } from '../controllers/leadController.js';
import { validateRequest } from '../middleware/validation.js';
import { auth } from '../middleware/auth.js';
import { leadSchema } from '../models/lead.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     Lead:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         fullName:
 *           type: string
 *         email:
 *           type: string, format: email
 *         phone:
 *           type: string
 *         budget:
 *           type: number
 *         desiredUnit:
 *           type: string
 *         source:
 *           type: string
 *           enum: [facebook, website, referral, other]
 *         stage:
 *           type: string
 *           enum: [nouveau, contacte, qualifie, visitePlanifiee, offreEnvoyee, negociation, bailSigne]
 *         notes:
 *           type: string
 *         tags:
 *           type: array
 *           items:
 *             type: string
 *         assignedAgentId:
 *           type: string
 *         createdAt:
 *           type: string, format: date-time
 *         updatedAt:
 *           type: string, format: date-time
 */

/**
 * @swagger
 * /api/leads:
 *   get:
 *     summary: Get all leads
 *     tags: [Leads]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: stage
 *         schema:
 *           type: string
 *           enum: [nouveau, contacte, qualifie, visitePlanifiee, offreEnvoyee, negociation, bailSigne]
 *         description: Filter by stage
 *       - in: query
 *         name: agentId
 *         schema:
 *           type: string
 *         description: Filter by assigned agent
 *       - in: query
 *         name: source
 *         schema:
 *           type: string
 *           enum: [facebook, website, referral, other]
 *         description: Filter by source
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         description: Number of items per page
 *     responses:
 *       200:
 *         description: Leads retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 leads:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Lead'
 *                 total:
 *                   type: number
 *                 page:
 *                   type: number
 *                 limit:
 *                   type: number
 */
router.get('/', auth, leadController.getAllLeads);

/**
 * @swagger
 * /api/leads/pipeline:
 *   get:
 *     summary: Get pipeline statistics
 *     tags: [Leads]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Pipeline statistics retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 stages:
 *                   type: object
 *                   additionalProperties:
 *                     type: number
 *                 totalLeads:
 *                   type: number
 *                 conversionRate:
 *                   type: number
 */
router.get('/pipeline', auth, leadController.getPipelineStats);

/**
 * @swagger
 * /api/leads/{id}:
 *   get:
 *     summary: Get lead by ID
 *     tags: [Leads]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Lead ID
 *     responses:
 *       200:
 *         description: Lead retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 lead:
 *                   $ref: '#/components/schemas/Lead'
 */
router.get('/:id', auth, leadController.getLeadById);

/**
 * @swagger
 * /api/leads:
 *   post:
 *     summary: Create new lead
 *     tags: [Leads]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - fullName
 *               - email
 *             properties:
 *               fullName:
 *                 type: string
 *               email:
 *                 type: string, format: email
 *               phone:
 *                 type: string
 *               budget:
 *                 type: number
 *               desiredUnit:
 *                 type: string
 *               source:
 *                 type: string
 *                 enum: [facebook, website, referral, other]
 *                 default: other
 *               stage:
 *                 type: string
 *                 enum: [nouveau, contacte, qualifie, visitePlanifiee, offreEnvoyee, negociation, bailSigne]
 *                 default: nouveau
 *               notes:
 *                 type: string
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *               assignedAgentId:
 *                 type: string
 *     responses:
 *       201:
 *         description: Lead created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 lead:
 *                   $ref: '#/components/schemas/Lead'
 */
router.post('/', auth, validateRequest(leadSchema), leadController.createLead);

/**
 * @swagger
 * /api/leads/{id}:
 *   put:
 *     summary: Update lead
 *     tags: [Leads]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Lead ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               fullName:
 *                 type: string
 *               email:
 *                 type: string, format: email
 *               phone:
 *                 type: string
 *               budget:
 *                 type: number
 *               desiredUnit:
 *                 type: string
 *               source:
 *                 type: string
 *                 enum: [facebook, website, referral, other]
 *               stage:
 *                 type: string
 *                 enum: [nouveau, contacte, qualifie, visitePlanifiee, offreEnvoyee, negociation, bailSigne]
 *               notes:
 *                 type: string
 *               tags:
 *                 type: array
 *                 items:
 *                   type: string
 *               assignedAgentId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Lead updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 lead:
 *                   $ref: '#/components/schemas/Lead'
 */
router.put('/:id', auth, validateRequest(leadSchema), leadController.updateLead);

/**
 * @swagger
 * /api/leads/{id}/stage:
 *   patch:
 *     summary: Update lead stage
 *     tags: [Leads]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Lead ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - stage
 *             properties:
 *               stage:
 *                 type: string
 *                 enum: [nouveau, contacte, qualifie, visitePlanifiee, offreEnvoyee, negociation, bailSigne]
 *               notes:
 *                 type: string
 *     responses:
 *       200:
 *         description: Lead stage updated successfully
 */
router.patch('/:id/stage', auth, leadController.updateLeadStage);

/**
 * @swagger
 * /api/leads/{id}:
 *   delete:
 *     summary: Delete lead
 *     tags: [Leads]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Lead ID
 *     responses:
 *       200:
 *         description: Lead deleted successfully
 */
router.delete('/:id', auth, leadController.deleteLead);

/**
 * @swagger
 * /api/leads/{id}/contact:
 *   post:
 *     summary: Mark lead as contacted
 *     tags: [Leads]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Lead ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               notes:
 *                 type: string
 *               nextContact:
 *                 type: string, format: date-time
 *     responses:
 *       200:
 *         description: Lead contact recorded successfully
 */
router.post('/:id/contact', auth, leadController.recordContact);

export default router;