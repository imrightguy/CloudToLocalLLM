import express from 'express';
import { visitController } from '../controllers/visitController.js';
import { validateRequest } from '../middleware/validation.js';
import { auth } from '../middleware/auth.js';
import { visitSchema } from '../models/visit.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     Visit:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         unitLabel:
 *           type: string
 *         buildingName:
 *           type: string
 *         dateTime:
 *           type: string, format: date-time
 *         status:
 *           type: string
 *           enum: [scheduled, confirmed, potential, completed, cancelled]
 *         agentId:
 *           type: string
 *         clientId:
 *           type: string
 *         notes:
 *           type: string
 *         followUp:
 *           type: string
 *         createdAt:
 *           type: string, format: date-time
 *         updatedAt:
 *           type: string, format: date-time
 */

/**
 * @swagger
 * /api/visits:
 *   get:
 *     summary: Get all visits
 *     tags: [Visits]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: date
 *         schema:
 *           type: string, format: date
 *         description: Filter by date (YYYY-MM-DD)
 *       - in: query
 *         name: agentId
 *         schema:
 *           type: string
 *         description: Filter by agent ID
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [scheduled, confirmed, potential, completed, cancelled]
 *         description: Filter by status
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
 *         description: Visits retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 visits:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Visit'
 *                 total:
 *                   type: number
 *                 page:
 *                   type: number
 *                 limit:
 *                   type: number
 */
router.get('/', auth, visitController.getAllVisits);

/**
 * @swagger
 * /api/visits/today:
 *   get:
 *     summary: Get today's visits
 *     tags: [Visits]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Today's visits retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Visit'
 */
router.get('/today', auth, visitController.getTodaysVisits);

/**
 * @swagger
 * /api/visits/{id}:
 *   get:
 *     summary: Get visit by ID
 *     tags: [Visits]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Visit ID
 *     responses:
 *       200:
 *         description: Visit retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 visit:
 *                   $ref: '#/components/schemas/Visit'
 */
router.get('/:id', auth, visitController.getVisitById);

/**
 * @swagger
 * /api/visits:
 *   post:
 *     summary: Create new visit
 *     tags: [Visits]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - unitLabel
 *               - buildingName
 *               - dateTime
 *               - agentId
 *               - clientId
 *             properties:
 *               unitLabel:
 *                 type: string
 *               buildingName:
 *                 type: string
 *               dateTime:
 *                 type: string, format: date-time
 *               status:
 *                 type: string
 *                 enum: [scheduled, confirmed, potential, completed, cancelled]
 *                 default: scheduled
 *               agentId:
 *                 type: string
 *               clientId:
 *                 type: string
 *               notes:
 *                 type: string
 *               followUp:
 *                 type: string
 *     responses:
 *       201:
 *         description: Visit created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 visit:
 *                   $ref: '#/components/schemas/Visit'
 */
router.post('/', auth, validateRequest(visitSchema), visitController.createVisit);

/**
 * @swagger
 * /api/visits/{id}:
 *   put:
 *     summary: Update visit
 *     tags: [Visits]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Visit ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               unitLabel:
 *                 type: string
 *               buildingName:
 *                 type: string
 *               dateTime:
 *                 type: string, format: date-time
 *               status:
 *                 type: string
 *                 enum: [scheduled, confirmed, potential, completed, cancelled]
 *               agentId:
 *                 type: string
 *               clientId:
 *                 type: string
 *               notes:
 *                 type: string
 *               followUp:
 *                 type: string
 *     responses:
 *       200:
 *         description: Visit updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 visit:
 *                   $ref: '#/components/schemas/Visit'
 */
router.put('/:id', auth, validateRequest(visitSchema), visitController.updateVisit);

/**
 * @swagger
 * /api/visits/{id}/status:
 *   patch:
 *     summary: Update visit status
 *     tags: [Visits]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Visit ID
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
 *                 enum: [scheduled, confirmed, potential, completed, cancelled]
 *     responses:
 *       200:
 *         description: Visit status updated successfully
 */
router.patch('/:id/status', auth, visitController.updateVisitStatus);

/**
 * @swagger
 * /api/visits/{id}:
 *   delete:
 *     summary: Delete visit
 *     tags: [Visits]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Visit ID
 *     responses:
 *       200:
 *         description: Visit deleted successfully
 */
router.delete('/:id', auth, visitController.deleteVisit);

export default router;