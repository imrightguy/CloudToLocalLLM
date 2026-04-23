const express = require('express');

const router = express.Router();
const visitController = require('../controllers/visit.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { visitSchemas, uuidParam } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/visits:
 *   get:
 *     tags: [Visits]
 *     summary: List all visits
 *     description: Returns a paginated list of visits with optional filtering.
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
 *           enum: [scheduled, confirmed, completed, cancelled, no_show]
 *       - in: query
 *         name: employeeId
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: leadId
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: dateFrom
 *         schema:
 *           type: string
 *           format: date
 *       - in: query
 *         name: dateTo
 *         schema:
 *           type: string
 *           format: date
 *       - in: query
 *         name: sortBy
 *         schema:
 *           type: string
 *           enum: [dateTime, createdAt, status, durationMinutes, updatedAt]
 *           default: dateTime
 *       - in: query
 *         name: sortOrder
 *         schema:
 *           type: string
 *           enum: [asc, desc]
 *           default: desc
 *       - in: query
 *         name: expand
 *         schema:
 *           type: string
 *           example: unit,building,employee,lead
 *     responses:
 *       200:
 *         description: List of visits
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
 *                         $ref: '#/components/schemas/Visit'
 *                     metadata:
 *                       $ref: '#/components/schemas/PaginationMeta'
 */
router.get('/', authenticateToken, validate(visitSchemas.list), asyncHandler(visitController.getVisits));

/**
 * @swagger
 * /api/visits:
 *   post:
 *     tags: [Visits]
 *     summary: Create a visit
 *     description: Schedule a new property visit for a lead.
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
 *               - employeeId
 *               - leadId
 *               - dateTime
 *             properties:
 *               unitId:
 *                 type: string
 *                 format: uuid
 *               employeeId:
 *                 type: string
 *                 format: uuid
 *               leadId:
 *                 type: string
 *                 format: uuid
 *               dateTime:
 *                 type: string
 *                 format: date-time
 *                 example: "2026-05-15T14:00:00Z"
 *               durationMinutes:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 1440
 *                 default: 30
 *               status:
 *                 type: string
 *                 enum: [scheduled, confirmed, completed, cancelled, no_show]
 *               notes:
 *                 type: string
 *     responses:
 *       201:
 *         description: Visit created
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Visit'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/', authenticateToken, validate(visitSchemas.create), asyncHandler(visitController.createVisit));

/**
 * @swagger
 * /api/visits/{id}:
 *   get:
 *     tags: [Visits]
 *     summary: Get visit by ID
 *     description: Returns a single visit with full details.
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
 *         description: Visit details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Visit'
 *       404:
 *         description: Visit not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/:id', authenticateToken, validate(uuidParam), asyncHandler(visitController.getVisitById));

/**
 * @swagger
 * /api/visits/{id}:
 *   put:
 *     tags: [Visits]
 *     summary: Update a visit
 *     description: Update visit details (reschedule, change assignee, etc.).
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
 *               unitId:
 *                 type: string
 *                 format: uuid
 *               employeeId:
 *                 type: string
 *                 format: uuid
 *               leadId:
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
 *                 enum: [scheduled, confirmed, completed, cancelled, no_show]
 *               tenantConfirmed:
 *                 type: boolean
 *               employeeConfirmed:
 *                 type: boolean
 *               morningOfSent:
 *                 type: boolean
 *               outcome:
 *                 type: string
 *                 nullable: true
 *                 enum: [interesse, pas_interesse, no_show]
 *               notes:
 *                 type: string
 *     responses:
 *       200:
 *         description: Visit updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Visit'
 *       404:
 *         description: Visit not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.put('/:id', authenticateToken, validate(visitSchemas.update), asyncHandler(visitController.updateVisit));

/**
 * @swagger
 * /api/visits/{id}:
 *   delete:
 *     tags: [Visits]
 *     summary: Delete a visit
 *     description: Cancel and delete a scheduled visit.
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
 *         description: Visit deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Visit not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/:id', authenticateToken, validate(uuidParam), asyncHandler(visitController.deleteVisit));

/**
 * @swagger
 * /api/visits/{id}/status:
 *   patch:
 *     tags: [Visits]
 *     summary: Update visit status
 *     description: Change the status of a visit (confirm, complete, cancel, or mark no-show).
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
 *                 enum: [scheduled, confirmed, completed, cancelled, no_show]
 *               outcome:
 *                 type: string
 *                 nullable: true
 *                 enum: [interesse, pas_interesse, no_show]
 *               notes:
 *                 type: string
 *     responses:
 *       200:
 *         description: Visit status updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Visit'
 */
router.patch('/:id/status', authenticateToken, validate(visitSchemas.updateStatus), asyncHandler(visitController.updateVisitStatus));

module.exports = router;
