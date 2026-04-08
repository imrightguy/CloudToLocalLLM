import express from 'express';
import { buildingController } from '../controllers/buildingController.js';
import { validateRequest } from '../middleware/validation.js';
import { auth } from '../middleware/auth.js';
import { buildingSchema } from '../models/building.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     Building:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         name:
 *           type: string
 *         address:
 *           type: string
 *         totalUnits:
 *           type: number
 *         occupiedUnits:
 *           type: number
 *         monthlyRevenue:
 *           type: number
 *         manager:
 *           type: string
 *         properties:
 *           type: object
 *           properties:
 *             yearBuilt:
 *               type: number
 *             type:
 *               type: string
 *             amenities:
 *               type: array
 *               items:
 *                 type: string
 */

/**
 * @swagger
 * /api/buildings:
 *   get:
 *     summary: Get all buildings
 *     tags: [Buildings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
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
 *         description: Buildings retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 buildings:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Building'
 *                 total:
 *                   type: number
 *                 page:
 *                   type: number
 *                 limit:
 *                   type: number
 */
router.get('/', auth, buildingController.getAllBuildings);

/**
 * @swagger
 * /api/buildings/{id}:
 *   get:
 *     summary: Get building by ID
 *     tags: [Buildings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Building ID
 *     responses:
 *       200:
 *         description: Building retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 building:
 *                   $ref: '#/components/schemas/Building'
 */
router.get('/:id', auth, buildingController.getBuildingById);

/**
 * @swagger
 * /api/buildings:
 *   post:
 *     summary: Create new building
 *     tags: [Buildings]
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
 *               - address
 *               - totalUnits
 *             properties:
 *               name:
 *                 type: string
 *               address:
 *                 type: string
 *               totalUnits:
 *                 type: number
 *               manager:
 *                 type: string
 *               properties:
 *                 type: object
 *                 properties:
 *                   yearBuilt:
 *                     type: number
 *                   type:
 *                     type: string
 *                   amenities:
 *                     type: array
 *                     items:
 *                       type: string
 *     responses:
 *       201:
 *         description: Building created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 building:
 *                   $ref: '#/components/schemas/Building'
 */
router.post('/', auth, validateRequest(buildingSchema), buildingController.createBuilding);

/**
 * @swagger
 * /api/buildings/{id}:
 *   put:
 *     summary: Update building
 *     tags: [Buildings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Building ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               address:
 *                 type: string
 *               totalUnits:
 *                 type: number
 *               manager:
 *                 type: string
 *               properties:
 *                 type: object
 *                 properties:
 *                   yearBuilt:
 *                     type: number
 *                   type:
 *                     type: string
 *                   amenities:
 *                     type: array
 *                     items:
 *                       type: string
 *     responses:
 *       200:
 *         description: Building updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 building:
 *                   $ref: '#/components/schemas/Building'
 */
router.put('/:id', auth, validateRequest(buildingSchema), buildingController.updateBuilding);

/**
 * @swagger
 * /api/buildings/{id}:
 *   delete:
 *     summary: Delete building
 *     tags: [Buildings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Building ID
 *     responses:
 *       200:
 *         description: Building deleted successfully
 */
router.delete('/:id', auth, buildingController.deleteBuilding);

export default router;