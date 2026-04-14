// ─── Analytics Routes — Phase 4 ───
const express = require('express');

const router = express.Router();
const analyticsController = require('../controllers/analytics.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

// ─── Dashboard ───
router.get('/dashboard', authenticateToken, asyncHandler(analyticsController.getDashboard));

// ─── Leads Analytics ───
router.get('/leads/pipeline', authenticateToken, asyncHandler(analyticsController.getPipeline));
router.get('/leads/hot', authenticateToken, asyncHandler(analyticsController.getHotLeads));

// ─── Visits Analytics ───
router.get('/visits/stats', authenticateToken, asyncHandler(analyticsController.getVisitStats));
router.get('/visits/conversion', authenticateToken, asyncHandler(analyticsController.getConversionRates));

// ─── No-Show Patterns ───
router.get('/noshow-patterns', authenticateToken, asyncHandler(analyticsController.getNoShowPatterns));

// ─── Building Performance ───
router.get('/buildings/:id/performance', authenticateToken, asyncHandler(analyticsController.getBuildingPerformance));

// ─── Employee Performance ───
router.get('/employees/:id/performance', authenticateToken, asyncHandler(analyticsController.getEmployeePerformance));

// ─── Weekly Summary ───
router.get('/weekly-summary', authenticateToken, asyncHandler(analyticsController.getWeeklySummary));

// ─── Time-Series Analytics ───
router.get('/occupancy-trend', authenticateToken, asyncHandler(analyticsController.getOccupancyTrend));
router.get('/revenue-trend', authenticateToken, asyncHandler(analyticsController.getRevenueTrend));
router.get('/lead-funnel', authenticateToken, asyncHandler(analyticsController.getLeadFunnel));
router.get('/visit-metrics', authenticateToken, asyncHandler(analyticsController.getVisitMetrics));

module.exports = router;
