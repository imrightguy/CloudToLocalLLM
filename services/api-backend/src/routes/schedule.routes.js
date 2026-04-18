const express = require('express');

const router = express.Router();
const scheduleController = require('../controllers/schedule.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { scheduleSchemas, uuidParam } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/schedules:
 *   get:
 *     tags: [Schedules]
 *     summary: List all schedules
 *     description: Returns a list of employee work schedules.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: employeeId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by employee
 *     responses:
 *       200:
 *         description: List of schedules
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
 *                         $ref: '#/components/schemas/Schedule'
 */
router.get('/', authenticateToken, asyncHandler(scheduleController.getSchedules));

/**
 * @swagger
 * /api/schedules:
 *   post:
 *     tags: [Schedules]
 *     summary: Create a schedule
 *     description: Create a new work schedule entry for an employee.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - employeeId
 *               - dayOfWeek
 *               - startTime
 *               - endTime
 *             properties:
 *               employeeId:
 *                 type: string
 *                 format: uuid
 *               dayOfWeek:
 *                 type: integer
 *                 minimum: 0
 *                 maximum: 6
 *                 description: "0 = Sunday, 6 = Saturday"
 *                 example: 1
 *               startTime:
 *                 type: string
 *                 example: "09:00"
 *               endTime:
 *                 type: string
 *                 example: "17:00"
 *               isAvailable:
 *                 type: boolean
 *                 default: true
 *     responses:
 *       201:
 *         description: Schedule created
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Schedule'
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/', authenticateToken, validate(scheduleSchemas.create), asyncHandler(scheduleController.createSchedule));

/**
 * @swagger
 * /api/schedules/{id}:
 *   get:
 *     tags: [Schedules]
 *     summary: Get schedule by ID
 *     description: Returns a single schedule entry.
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
 *         description: Schedule details
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Schedule'
 *       404:
 *         description: Schedule not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/:id', authenticateToken, asyncHandler(scheduleController.getScheduleById));

/**
 * @swagger
 * /api/schedules/{id}:
 *   put:
 *     tags: [Schedules]
 *     summary: Update a schedule
 *     description: Update a schedule entry.
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
 *               dayOfWeek:
 *                 type: integer
 *                 minimum: 0
 *                 maximum: 6
 *               startTime:
 *                 type: string
 *               endTime:
 *                 type: string
 *               isAvailable:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Schedule updated
 *         content:
 *           application/json:
 *             schema:
 *               allOf:
 *                 - $ref: '#/components/schemas/SuccessResponse'
 *                 - type: object
 *                   properties:
 *                     data:
 *                       $ref: '#/components/schemas/Schedule'
 *       404:
 *         description: Schedule not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.put('/:id', authenticateToken, validate(scheduleSchemas.update), asyncHandler(scheduleController.updateSchedule));

/**
 * @swagger
 * /api/schedules/{id}:
 *   delete:
 *     tags: [Schedules]
 *     summary: Delete a schedule
 *     description: Delete a schedule entry.
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
 *         description: Schedule deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       404:
 *         description: Schedule not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/:id', authenticateToken, validate(uuidParam), asyncHandler(scheduleController.deleteSchedule));

/**
 * @swagger
 * /api/schedules/employee/{employeeId}/availability:
 *   get:
 *     tags: [Schedules]
 *     summary: Get employee availability
 *     description: Returns available time slots for an employee on a specific date.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: employeeId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Employee ID
 *       - in: query
 *         name: date
 *         required: true
 *         schema:
 *           type: string
 *           format: date
 *         description: Date to check availability
 *         example: "2026-05-15"
 *     responses:
 *       200:
 *         description: Available time slots
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
 *                         employeeId: { type: string, format: uuid }
 *                         date: { type: string, format: date }
 *                         slots:
 *                           type: array
 *                           items:
 *                             type: object
 *                             properties:
 *                               startTime: { type: string }
 *                               endTime: { type: string }
 *                               isAvailable: { type: boolean }
 */
router.get('/employee/:employeeId/availability', authenticateToken, asyncHandler((req, res) => scheduleController.getEmployeeAvailability(req, res, req.params.employeeId, req.query.date)));

module.exports = router;
