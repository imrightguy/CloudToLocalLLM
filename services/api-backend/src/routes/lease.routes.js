const express = require('express');

const router = express.Router();
const leaseController = require('../controllers/lease.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

/**
 * @swagger
 * /api/leases:
 *   get:
 *     tags: [Leases]
 *     summary: List all leases
 *     description: Returns a paginated list of leases with optional filtering.
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
 *           enum: [draft, active, expired, terminated]
 *         description: Filter by lease status
 *       - in: query
 *         name: buildingId
 *         schema:
 *           type: string
 *           format: uuid
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
 *                     meta:
 *                       $ref: '#/components/schemas/PaginationMeta'
 */
router.get('/', authenticateToken, asyncHandler(leaseController.getLeases));

/**
 * @swagger
 * /api/leases:
 *   post:
 *     tags: [Leases]
 *     summary: Create a lease
 *     description: Create a new lease agreement.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - unitId
 *               - tenantId
 *               - startDate
 *               - endDate
 *               - rentAmount
 *             properties:
 *               unitId:
 *                 type: string
 *                 format: uuid
 *               buildingId:
 *                 type: string
 *                 format: uuid
 *               tenantId:
 *                 type: string
 *                 format: uuid
 *               startDate:
 *                 type: string
 *                 format: date
 *                 example: "2026-07-01"
 *               endDate:
 *                 type: string
 *                 format: date
 *                 example: "2027-06-30"
 *               rentAmount:
 *                 type: number
 *                 example: 1200
 *     responses:
 *       201:
 *         description: Lease created
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lease'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/', authenticateToken, asyncHandler(leaseController.createLease));

/**
 * @swagger
 * /api/leases/building/{id}:
 *   get:
 *     tags: [Leases]
 *     summary: Get leases by building
 *     description: Returns all leases for a specific building.
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
 *         description: List of leases for the building
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
router.get('/building/:id', authenticateToken, asyncHandler(leaseController.getLeasesByBuilding));

/**
 * @swagger
 * /api/leases/unit/{id}:
 *   get:
 *     tags: [Leases]
 *     summary: Get leases by unit
 *     description: Returns all leases for a specific unit.
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
 *         description: List of leases for the unit
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
router.get('/unit/:id', authenticateToken, asyncHandler(leaseController.getLeasesByUnit));

/**
 * @swagger
 * /api/leases/{id}:
 *   get:
 *     tags: [Leases]
 *     summary: Get lease by ID
 *     description: Returns a single lease with full details.
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
 *         description: Lease details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lease'
 *       404:
 *         description: Lease not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/:id', authenticateToken, asyncHandler(leaseController.getLeaseById));

/**
 * @swagger
 * /api/leases/{id}:
 *   patch:
 *     tags: [Leases]
 *     summary: Update a lease
 *     description: Update lease details (dates, rent amount, etc.).
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
 *               startDate:
 *                 type: string
 *                 format: date
 *               endDate:
 *                 type: string
 *                 format: date
 *               rentAmount:
 *                 type: number
 *     responses:
 *       200:
 *         description: Lease updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lease'
 *       404:
 *         description: Lease not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.patch('/:id', authenticateToken, asyncHandler(leaseController.updateLease));

/**
 * @swagger
 * /api/leases/{id}:
 *   delete:
 *     tags: [Leases]
 *     summary: Delete a lease
 *     description: Delete a lease agreement.
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
 *         description: Lease deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Lease not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/:id', authenticateToken, asyncHandler(leaseController.deleteLease));

/**
 * @swagger
 * /api/leases/{id}/status:
 *   patch:
 *     tags: [Leases]
 *     summary: Update lease status
 *     description: Change the status of a lease (activate, expire, terminate).
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
 *                 enum: [draft, active, expired, terminated]
 *     responses:
 *       200:
 *         description: Lease status updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lease'
 */
router.patch('/:id/status', authenticateToken, asyncHandler(leaseController.updateLeaseStatus));

/**
 * @swagger
 * /api/leases/{id}/sign:
 *   patch:
 *     tags: [Leases]
 *     summary: Sign a lease
 *     description: Record a digital signature on a lease. Moves the lease to active status.
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
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               signatureType:
 *                 type: string
 *                 enum: [tenant, landlord, both]
 *                 default: tenant
 *     responses:
 *       200:
 *         description: Lease signed
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Lease'
 *       400:
 *         description: Lease cannot be signed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.patch('/:id/sign', authenticateToken, asyncHandler(leaseController.signLease));

module.exports = router;
