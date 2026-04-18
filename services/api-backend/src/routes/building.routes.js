const express = require('express');

const router = express.Router();
const buildingController = require('../controllers/building.controller');
const leaseController = require('../controllers/lease.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { buildingSchemas, uuidParam } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/buildings:
 *   get:
 *     tags: [Buildings]
 *     summary: List all buildings
 *     description: Returns a paginated list of all buildings.
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
 *         name: search
 *         schema:
 *           type: string
 *         description: Search by name or address
 *     responses:
 *       200:
 *         description: List of buildings
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
 *                         $ref: '#/components/schemas/Building'
 *                     meta:
 *                       $ref: '#/components/schemas/PaginationMeta'
 *       401:
 *         description: Not authenticated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/', authenticateToken, asyncHandler(buildingController.getBuildings));

/**
 * @swagger
 * /api/buildings:
 *   post:
 *     tags: [Buildings]
 *     summary: Create a building
 *     description: Create a new building.
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
 *               - city
 *             properties:
 *               name:
 *                 type: string
 *                 example: 123 Rue Sainte-Catherine
 *               address:
 *                 type: string
 *                 example: 123 Rue Sainte-Catherine
 *               city:
 *                 type: string
 *                 example: Montreal
 *               province:
 *                 type: string
 *                 example: QC
 *               postalCode:
 *                 type: string
 *                 example: H2X 1Y4
 *               totalUnits:
 *                 type: integer
 *                 example: 12
 *     responses:
 *       201:
 *         description: Building created
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Building'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
router.post('/', authenticateToken, validate(buildingSchemas.create), asyncHandler(buildingController.createBuilding));

/**
 * @swagger
 * /api/buildings/units:
 *   get:
 *     tags: [Buildings]
 *     summary: List all units
 *     description: Returns a paginated list of all units across buildings.
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
 *         name: buildingId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by building ID
 *       - in: query
 *         name: isAvailable
 *         schema:
 *           type: boolean
 *         description: Filter by availability
 *     responses:
 *       200:
 *         description: List of units
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
 *                         $ref: '#/components/schemas/Unit'
 *                     meta:
 *                       $ref: '#/components/schemas/PaginationMeta'
 */
router.get('/units', authenticateToken, asyncHandler(buildingController.getUnits));

/**
 * @swagger
 * /api/buildings/units:
 *   post:
 *     tags: [Buildings]
 *     summary: Create a unit
 *     description: Create a new unit in a building.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - buildingId
 *               - unitNumber
 *             properties:
 *               buildingId:
 *                 type: string
 *                 format: uuid
 *               unitNumber:
 *                 type: string
 *                 example: "4B"
 *               type:
 *                 type: string
 *                 enum: [studio, 1br, 2br, 3br, 4br, other]
 *               rentAmount:
 *                 type: number
 *                 example: 1200
 *               sqft:
 *                 type: integer
 *                 example: 750
 *               isAvailable:
 *                 type: boolean
 *                 default: true
 *               bedrooms:
 *                 type: integer
 *               bathrooms:
 *                 type: integer
 *     responses:
 *       201:
 *         description: Unit created
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Unit'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/units', authenticateToken, validate(buildingSchemas.createUnit), asyncHandler(buildingController.createUnit));

/**
 * @swagger
 * /api/buildings/units/{id}:
 *   get:
 *     tags: [Buildings]
 *     summary: Get unit by ID
 *     description: Returns a single unit with its details.
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
 *         description: Unit details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Unit'
 *       404:
 *         description: Unit not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/units/:id', authenticateToken, validate(uuidParam), asyncHandler(buildingController.getUnitById));

/**
 * @swagger
 * /api/buildings/units/{id}/leases:
 *   get:
 *     tags: [Buildings]
 *     summary: Get leases for a unit
 *     description: Returns all leases associated with a specific unit.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Unit ID
 *     responses:
 *       200:
 *         description: List of leases
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
 *                         $ref: '#/components/schemas/Lease'
 */
router.get('/units/:id/leases', authenticateToken, validate(uuidParam), asyncHandler(leaseController.getLeasesByUnit));

/**
 * @swagger
 * /api/buildings/units/{id}:
 *   put:
 *     tags: [Buildings]
 *     summary: Update a unit
 *     description: Update a unit's information.
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
 *               unitNumber:
 *                 type: string
 *               type:
 *                 type: string
 *                 enum: [studio, 1br, 2br, 3br, 4br, other]
 *               rentAmount:
 *                 type: number
 *               sqft:
 *                 type: integer
 *               isAvailable:
 *                 type: boolean
 *               bedrooms:
 *                 type: integer
 *               bathrooms:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Unit updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Unit'
 *       404:
 *         description: Unit not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.put('/units/:id', authenticateToken, validate(buildingSchemas.updateUnit), asyncHandler(buildingController.updateUnit));

/**
 * @swagger
 * /api/buildings/units/{id}:
 *   delete:
 *     tags: [Buildings]
 *     summary: Delete a unit
 *     description: Delete a unit.
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
 *         description: Unit deleted
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Unit not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/units/:id', authenticateToken, validate(uuidParam), asyncHandler(buildingController.deleteUnit));

/**
 * @swagger
 * /api/buildings/{id}:
 *   get:
 *     tags: [Buildings]
 *     summary: Get building by ID
 *     description: Returns a single building with its details.
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
 *         description: Building details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Building'
 *       404:
 *         description: Building not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/:id', authenticateToken, validate(uuidParam), asyncHandler(buildingController.getBuildingById));

/**
 * @swagger
 * /api/buildings/{id}/leases:
 *   get:
 *     tags: [Buildings]
 *     summary: Get leases for a building
 *     description: Returns all leases associated with a specific building.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Building ID
 *     responses:
 *       200:
 *         description: List of leases
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
 *                         $ref: '#/components/schemas/Lease'
 *       404:
 *         description: Building not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/:id/leases', authenticateToken, validate(uuidParam), asyncHandler(leaseController.getLeasesByBuilding));

/**
 * @swagger
 * /api/buildings/{id}:
 *   put:
 *     tags: [Buildings]
 *     summary: Update a building
 *     description: Update a building's information.
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
 *               address:
 *                 type: string
 *               city:
 *                 type: string
 *               province:
 *                 type: string
 *               postalCode:
 *                 type: string
 *               totalUnits:
 *                 type: integer
 *     responses:
 *       200:
 *         description: Building updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Building'
 *       404:
 *         description: Building not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.put('/:id', authenticateToken, validate(buildingSchemas.update), asyncHandler(buildingController.updateBuilding));

/**
 * @swagger
 * /api/buildings/{id}:
 *   delete:
 *     tags: [Buildings]
 *     summary: Delete a building
 *     description: Delete a building and all associated units.
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
 *         description: Building deleted
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Building not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/:id', authenticateToken, validate(uuidParam), asyncHandler(buildingController.deleteBuilding));
module.exports = router;
