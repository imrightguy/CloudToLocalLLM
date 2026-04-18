// ─── Analytics Routes — Phase 4 ───
const express = require('express');

const router = express.Router();
const analyticsController = require('../controllers/analytics.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { analyticsSchemas } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/analytics/dashboard:
 *   get:
 *     tags: [Analytics]
 *     summary: Dashboard overview
 *     description: Returns high-level KPIs: total leads, visits, leases, revenue, occupancy rate.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: period
 *         schema:
 *           type: string
 *           enum: [today, week, month, quarter, year]
 *           default: month
 *     responses:
 *       200:
 *         description: Dashboard metrics
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
 *                         totalLeads: { type: integer }
 *                         totalVisits: { type: integer }
 *                         activeLeases: { type: integer }
 *                         occupancyRate: { type: number }
 *                         monthlyRevenue: { type: number }
 *                         conversionRate: { type: number }
 */
router.get('/dashboard', authenticateToken, validate(analyticsSchemas.dashboard), asyncHandler(analyticsController.getDashboard));

/**
 * @swagger
 * /api/analytics/leads/pipeline:
 *   get:
 *     tags: [Analytics]
 *     summary: Lead pipeline breakdown
 *     description: Returns the number of leads at each pipeline stage.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Pipeline stages with lead counts
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
 *                         type: object
 *                         properties:
 *                           stage: { type: string }
 *                           count: { type: integer }
 */
router.get('/leads/pipeline', authenticateToken, asyncHandler(analyticsController.getPipeline));

/**
 * @swagger
 * /api/analytics/leads/hot:
 *   get:
 *     tags: [Analytics]
 *     summary: Hot leads
 *     description: Returns leads most likely to convert based on engagement scoring.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 10
 *     responses:
 *       200:
 *         description: Hot leads list
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
 *                         $ref: '#/components/schemas/Lead'
 */
router.get('/leads/hot', authenticateToken, validate(analyticsSchemas.hotLeads), asyncHandler(analyticsController.getHotLeads));

/**
 * @swagger
 * /api/analytics/visits/stats:
 *   get:
 *     tags: [Analytics]
 *     summary: Visit statistics
 *     description: Returns visit statistics: total, completed, cancelled, no-show counts.
 *     security:
 *       - bearerAuth: []
 *     parameters:
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
 *     responses:
 *       200:
 *         description: Visit statistics
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
 *                         total: { type: integer }
 *                         completed: { type: integer }
 *                         cancelled: { type: integer }
 *                         noShow: { type: integer }
 */
router.get('/visits/stats', authenticateToken, validate(analyticsSchemas.visitStats), asyncHandler(analyticsController.getVisitStats));

/**
 * @swagger
 * /api/analytics/visits/conversion:
 *   get:
 *     tags: [Analytics]
 *     summary: Visit conversion rates
 *     description: Returns conversion rates from visit to lease by building and time period.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Conversion rate data
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
 *                         overallRate: { type: number }
 *                         byBuilding:
 *                           type: array
 *                           items:
 *                             type: object
 *                             properties:
 *                               buildingId: { type: string }
 *                               buildingName: { type: string }
 *                               rate: { type: number }
 */
router.get('/visits/conversion', authenticateToken, asyncHandler(analyticsController.getConversionRates));

/**
 * @swagger
 * /api/analytics/noshow-patterns:
 *   get:
 *     tags: [Analytics]
 *     summary: No-show patterns
 *     description: Analyzes patterns in no-show visits (time, building, lead source).
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: No-show pattern analysis
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
 *                         byDayOfWeek:
 *                           type: array
 *                           items:
 *                             type: object
 *                             properties:
 *                               day: { type: string }
 *                               noShowRate: { type: number }
 *                         byHour:
 *                           type: array
 *                           items:
 *                             type: object
 *                             properties:
 *                               hour: { type: integer }
 *                               noShowRate: { type: number }
 */
router.get('/noshow-patterns', authenticateToken, asyncHandler(analyticsController.getNoShowPatterns));

/**
 * @swagger
 * /api/analytics/buildings/{id}/performance:
 *   get:
 *     tags: [Analytics]
 *     summary: Building performance
 *     description: Returns performance metrics for a specific building (occupancy, revenue, lead-to-lease rate).
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
 *         description: Building performance data
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
 *                         buildingId: { type: string }
 *                         occupancyRate: { type: number }
 *                         monthlyRevenue: { type: number }
 *                         totalUnits: { type: integer }
 *                         occupiedUnits: { type: integer }
 *                         activeLeases: { type: integer }
 */
router.get('/buildings/:id/performance', authenticateToken, validate(analyticsSchemas.buildingPerformance), asyncHandler(analyticsController.getBuildingPerformance));

/**
 * @swagger
 * /api/analytics/employees/{id}/performance:
 *   get:
 *     tags: [Analytics]
 *     summary: Employee performance
 *     description: >
 *       Returns performance metrics for a specific employee
 *       (visits completed, leases signed, conversion rate).
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Employee ID
 *     responses:
 *       200:
 *         description: Employee performance data
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
 *                         employeeId: { type: string }
 *                         visitsCompleted: { type: integer }
 *                         leasesSigned: { type: integer }
 *                         conversionRate: { type: number }
 *                         noShowRate: { type: number }
 */
router.get('/employees/:id/performance', authenticateToken, validate(analyticsSchemas.employeePerformance), asyncHandler(analyticsController.getEmployeePerformance));

/**
 * @swagger
 * /api/analytics/weekly-summary:
 *   get:
 *     tags: [Analytics]
 *     summary: Weekly summary
 *     description: Returns a summary of key metrics for the current week.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Weekly summary data
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
 *                         weekStart: { type: string, format: date }
 *                         weekEnd: { type: string, format: date }
 *                         newLeads: { type: integer }
 *                         visitsCompleted: { type: integer }
 *                         leasesSigned: { type: integer }
 *                         revenue: { type: number }
 */
router.get('/weekly-summary', authenticateToken, asyncHandler(analyticsController.getWeeklySummary));

/**
 * @swagger
 * /api/analytics/occupancy-trend:
 *   get:
 *     tags: [Analytics]
 *     summary: Occupancy trend
 *     description: Returns historical occupancy rate over time.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: months
 *         schema:
 *           type: integer
 *           default: 12
 *         description: Number of months to include
 *     responses:
 *       200:
 *         description: Occupancy trend data
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
 *                         type: object
 *                         properties:
 *                           month: { type: string }
 *                           occupancyRate: { type: number }
 */
router.get('/occupancy-trend', authenticateToken, validate(analyticsSchemas.trendMonths), asyncHandler(analyticsController.getOccupancyTrend));

/**
 * @swagger
 * /api/analytics/revenue-trend:
 *   get:
 *     tags: [Analytics]
 *     summary: Revenue trend
 *     description: Returns monthly revenue trend over time.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: months
 *         schema:
 *           type: integer
 *           default: 12
 *     responses:
 *       200:
 *         description: Revenue trend data
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
 *                         type: object
 *                         properties:
 *                           month: { type: string }
 *                           revenue: { type: number }
 */
router.get('/revenue-trend', authenticateToken, validate(analyticsSchemas.trendMonths), asyncHandler(analyticsController.getRevenueTrend));

/**
 * @swagger
 * /api/analytics/lead-funnel:
 *   get:
 *     tags: [Analytics]
 *     summary: Lead funnel
 *     description: Returns the lead conversion funnel showing drop-off at each stage.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Lead funnel data
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
 *                         type: object
 *                         properties:
 *                           stage: { type: string }
 *                           count: { type: integer }
 *                           conversionRate: { type: number }
 */
router.get('/lead-funnel', authenticateToken, asyncHandler(analyticsController.getLeadFunnel));

/**
 * @swagger
 * /api/analytics/visit-metrics:
 *   get:
 *     tags: [Analytics]
 *     summary: Visit metrics
 *     description: Returns detailed visit metrics including average duration and employee performance.
 *     security:
 *       - bearerAuth: []
 *     parameters:
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
 *     responses:
 *       200:
 *         description: Visit metrics
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
 *                         totalVisits: { type: integer }
 *                         avgDuration: { type: number }
 *                         completionRate: { type: number }
 *                         noShowRate: { type: number }
 */
router.get('/visit-metrics', authenticateToken, validate(analyticsSchemas.visitMetrics), asyncHandler(analyticsController.getVisitMetrics));

module.exports = router;
