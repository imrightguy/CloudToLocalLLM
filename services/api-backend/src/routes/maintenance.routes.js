const express = require('express');

const router = express.Router();
const maintenanceController = require('../controllers/maintenance.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { maintenanceSchemas } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/maintenance/command-center:
 *   get:
 *     tags: [Maintenance]
 *     summary: Get the maintenance command center
 *     description: Returns a read-only cross-property command center combining backlog, capacity, and tenant-message status.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: buildingId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Optional building filter for a single property view.
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 50
 *           default: 12
 *         description: Number of backlog items to return.
 *     responses:
 *       200:
 *         description: Maintenance command center payload
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
 *                         summary:
 *                           type: object
 *                           properties:
 *                             propertyCount:
 *                               type: integer
 *                             renovationCount:
 *                               type: integer
 *                             blockedCount:
 *                               type: integer
 *                             readyCount:
 *                               type: integer
 *                             overdueTaskCount:
 *                               type: integer
 *                             dueSoonTaskCount:
 *                               type: integer
 *                             openOrderCount:
 *                               type: integer
 *                             pendingIntakeCount:
 *                               type: integer
 *                             dispatchableEmployeeCount:
 *                               type: integer
 *                             tenantMessageSentCount:
 *                               type: integer
 *                             tenantMessageFailedCount:
 *                               type: integer
 *                             tenantMessagePendingCount:
 *                               type: integer
 *                         properties:
 *                           type: array
 *                         backlog:
 *                           type: array
 *                         tenantMessages:
 *                           type: array
 *                         reviewQueue:
 *                           type: object
 *                           properties:
 *                             summary:
 *                               type: object
 *                             recommendations:
 *                               type: array
 *                             asOf:
 *                               type: string
 *                               format: date-time
 *                         asOf:
 *                           type: string
 *                           format: date-time
 */
router.get('/command-center', authenticateToken, validate(maintenanceSchemas.commandCenter), asyncHandler(maintenanceController.getCommandCenter));

module.exports = router;
