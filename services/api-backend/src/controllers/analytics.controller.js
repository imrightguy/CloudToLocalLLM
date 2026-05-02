// ─── Analytics Controller — Phase 4 ───
const analyticsService = require('../services/analytics.service');
const logger = require('../utils/logger');
const { successResponse } = require('../utils/apiResponse');

const PERIODS = new Set(['30d', '90d', '12m']);
const GRANULARITIES = new Set(['day', 'week', 'month']);

// ─── Dashboard (full overview) ───

exports.getDashboard = async (req, res) => {
  try {
    const [pipeline, hotLeads, weeklyStats, visitStats, conversionRates, leadSources, inboxToVisitMetrics] = await Promise.all([
      analyticsService.getPipelineSummary(),
      analyticsService.getHotLeads(),
      analyticsService.getWeeklySummary(),
      analyticsService.getVisitStats('week'),
      analyticsService.getConversionRates('week'),
      analyticsService.getLeadSourceBreakdown(),
      analyticsService.getInboxToVisitMetrics(),
    ]);

    return res.json(successResponse({
      data: {
        pipeline,
        hotLeads,
        weeklyStats,
        visitStats,
        conversionRates,
        leadSources,
        inboxToVisitMetrics,
      },
    }));
  } catch (error) {
    logger.error('[analytics.controller] getDashboard error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load dashboard', code: 'DASHBOARD_ERROR' },
    });
  }
};

// ─── Pipeline Summary ───

exports.getPipeline = async (req, res) => {
  try {
    const data = await analyticsService.getPipelineSummary();
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getPipeline error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load pipeline', code: 'PIPELINE_ERROR' },
    });
  }
};

// ─── Hot Leads ───

exports.getHotLeads = async (req, res) => {
  try {
    const data = await analyticsService.getHotLeads();
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getHotLeads error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load hot leads', code: 'HOT_LEADS_ERROR' },
    });
  }
};

// ─── Visit Stats ───

exports.getVisitStats = async (req, res) => {
  try {
    const { period } = req.query;
    const data = await analyticsService.getVisitStats(period || 'week');
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getVisitStats error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load visit stats', code: 'VISIT_STATS_ERROR' },
    });
  }
};

// ─── Conversion Rates ───

exports.getConversionRates = async (req, res) => {
  try {
    const { period } = req.query;
    const data = await analyticsService.getConversionRates(period || 'week');
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getConversionRates error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load conversion rates', code: 'CONVERSION_ERROR' },
    });
  }
};

// ─── No-Show Patterns ───

exports.getNoShowPatterns = async (req, res) => {
  try {
    const { buildingId } = req.query;
    const data = await analyticsService.getNoShowPatterns(buildingId || null);
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getNoShowPatterns error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load no-show patterns', code: 'NOSHOW_ERROR' },
    });
  }
};

// ─── Building Performance ───

exports.getBuildingPerformance = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({
        success: false,
        error: { message: 'Building ID is required', code: 'VALIDATION_ERROR' },
      });
    }
    const data = await analyticsService.getBuildingPerformance(id);
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getBuildingPerformance error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load building performance', code: 'BUILDING_PERF_ERROR' },
    });
  }
};

// ─── Employee Performance ───

exports.getEmployeePerformance = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({
        success: false,
        error: { message: 'Employee ID is required', code: 'VALIDATION_ERROR' },
      });
    }
    const data = await analyticsService.getEmployeePerformance(id);
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getEmployeePerformance error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load employee performance', code: 'EMPLOYEE_PERF_ERROR' },
    });
  }
};

// ─── Weekly Summary ───

exports.getWeeklySummary = async (req, res) => {
  try {
    const data = await analyticsService.getWeeklySummary();
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getWeeklySummary error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load weekly summary', code: 'WEEKLY_SUMMARY_ERROR' },
    });
  }
};

// ─── Occupancy Trend ───

exports.getOccupancyTrend = async (req, res) => {
  try {
    const { buildingId } = req.query;
    const data = await analyticsService.getOccupancyTrend(buildingId || null);
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getOccupancyTrend error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load occupancy trend', code: 'OCCUPANCY_TREND_ERROR' },
    });
  }
};

// ─── Revenue Trend ───

exports.getRevenueTrend = async (req, res) => {
  try {
    const { period, buildingId, granularity } = req.query;
    const p = period || '12m';
    if (!PERIODS.has(p)) {
      return res.status(400).json({
        success: false,
        error: { message: `Invalid period. Must be one of: ${[...PERIODS].join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }
    const g = granularity || 'month';
    if (!GRANULARITIES.has(g)) {
      return res.status(400).json({
        success: false,
        error: { message: `Invalid granularity. Must be one of: ${[...GRANULARITIES].join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }
    const data = await analyticsService.getRevenueTrend(p, buildingId || null, g);
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getRevenueTrend error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load revenue trend', code: 'REVENUE_TREND_ERROR' },
    });
  }
};

// ─── Lead Funnel ───

exports.getLeadFunnel = async (req, res) => {
  try {
    const { period, buildingId, granularity } = req.query;
    const p = period || '90d';
    if (!PERIODS.has(p)) {
      return res.status(400).json({
        success: false,
        error: { message: `Invalid period. Must be one of: ${[...PERIODS].join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }
    const g = granularity || 'week';
    if (!GRANULARITIES.has(g)) {
      return res.status(400).json({
        success: false,
        error: { message: `Invalid granularity. Must be one of: ${[...GRANULARITIES].join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }
    const data = await analyticsService.getLeadFunnel(p, buildingId || null, g);
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getLeadFunnel error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load lead funnel', code: 'LEAD_FUNNEL_ERROR' },
    });
  }
};

// ─── Visit Metrics ───

exports.getVisitMetrics = async (req, res) => {
  try {
    const { period, buildingId, granularity } = req.query;
    const p = period || '30d';
    if (!PERIODS.has(p)) {
      return res.status(400).json({
        success: false,
        error: { message: `Invalid period. Must be one of: ${[...PERIODS].join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }
    const g = granularity || 'week';
    if (!GRANULARITIES.has(g)) {
      return res.status(400).json({
        success: false,
        error: { message: `Invalid granularity. Must be one of: ${[...GRANULARITIES].join(', ')}`, code: 'VALIDATION_ERROR' },
      });
    }
    const data = await analyticsService.getVisitMetrics(p, buildingId || null, g);
    return res.json(successResponse({ data }));
  } catch (error) {
    logger.error('[analytics.controller] getVisitMetrics error:', error);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to load visit metrics', code: 'VISIT_METRICS_ERROR' },
    });
  }
};
