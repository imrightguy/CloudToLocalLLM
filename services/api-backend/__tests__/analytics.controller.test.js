/**
 * Analytics Controller Tests
 *
 * Tests all 8 endpoints in analytics.controller.js:
 * - getDashboard, getPipeline, getHotLeads, getVisitStats,
 *   getConversionRates, getNoShowPatterns, getBuildingPerformance, getEmployeePerformance, getWeeklySummary
 *
 * Strategy: Mock analytics.service at the module level, verify correct
 * delegation and response formatting for success and error cases.
 */

// ─── Mocks ──────────────────────────────────────────────────────────────────────

const mockAnalyticsService = {
  getPipelineSummary: jest.fn(),
  getHotLeads: jest.fn(),
  getWeeklySummary: jest.fn(),
  getVisitStats: jest.fn(),
  getConversionRates: jest.fn(),
  getLeadSourceBreakdown: jest.fn(),
  getNoShowPatterns: jest.fn(),
  getBuildingPerformance: jest.fn(),
  getEmployeePerformance: jest.fn(),
  getOccupancyTrend: jest.fn(),
  getRevenueTrend: jest.fn(),
  getLeadFunnel: jest.fn(),
  getVisitMetrics: jest.fn(),
};

jest.mock('../src/services/analytics.service', () => mockAnalyticsService);

// Import after mocks
const {
  getDashboard,
  getPipeline,
  getHotLeads,
  getVisitStats,
  getConversionRates,
  getNoShowPatterns,
  getBuildingPerformance,
  getEmployeePerformance,
  getWeeklySummary,
  getOccupancyTrend,
  getRevenueTrend,
  getLeadFunnel,
  getVisitMetrics,
} = require('../src/controllers/analytics.controller');

// ─── Fixtures ───────────────────────────────────────────────────────────────────

const FIXTURES = {
  pipeline: {
    nouveau: 12,
    contacte: 8,
    visite_planifiee: 5,
    visite_confimee: 3,
    interesse: 2,
    pas_interesse: 4,
    total: 34,
  },
  hotLeads: [
    { id: 'lead-1', fullName: 'Marie Tremblay', stage: 'visite_planifiee', score: 85 },
    { id: 'lead-2', fullName: 'Jean Dupont', stage: 'visite_confimee', score: 92 },
  ],
  weeklyStats: {
    newLeads: 15,
    visitsScheduled: 8,
    visitsCompleted: 6,
    conversions: 3,
  },
  visitStats: {
    total: 25,
    completed: 18,
    noShows: 3,
    cancelled: 4,
    completionRate: 0.72,
  },
  conversionRates: {
    leadToVisit: 0.45,
    visitToInterested: 0.33,
    overallConversion: 0.15,
  },
  leadSources: {
    facebook: 18,
    google: 7,
    referral: 5,
    other: 4,
  },
  noShowPatterns: {
    byDayOfWeek: { 0: 2, 1: 1, 2: 3, 3: 0, 4: 2, 5: 4, 6: 1 },
    byTimeOfDay: { morning: 5, afternoon: 4, evening: 4 },
  },
  buildingPerformance: {
    buildingId: 'bldg-1',
    buildingName: '1234 Rue Saint-Laurent',
    totalLeads: 20,
    visitsScheduled: 12,
    visitsCompleted: 10,
    conversions: 4,
    conversionRate: 0.20,
  },
  employeePerformance: {
    employeeId: 'emp-1',
    employeeName: 'Jean Dupont',
    totalVisits: 15,
    completedVisits: 12,
    noShows: 1,
    conversions: 5,
    conversionRate: 0.42,
  },
  occupancyTrend: [
    { buildingId: 'bldg-1', buildingName: '1234 Rue Saint-Laurent', totalUnits: 20, occupiedUnits: 16, vacantUnits: 4, occupancyRate: 0.8 },
  ],
  revenueTrend: {
    data: [
      { date: '2026-01-01', value: 15000, buildingId: 'bldg-1', buildingName: '1234 Rue Saint-Laurent' },
    ],
    totals: [
      { date: '2026-01-01', value: 30000 },
    ],
  },
  leadFunnel: {
    stages: [{ stage: 'nouveau', count: 12 }, { stage: 'contacte', count: 8 }],
    conversionRate: '15.0%',
    timeline: [{ date: '2026-03-17', stage: 'nouveau', count: 3 }],
  },
  visitMetrics: {
    completionRate: '72.0%',
    noShowRate: '12.0%',
    avgTimeToLeaseDays: 14.5,
    totalVisits: 25,
    timeline: [{ date: '2026-03-17', completed: 5, cancelled: 1, noShow: 1 }],
  },
};

// ─── Helpers ────────────────────────────────────────────────────────────────────

function mockReqRes(overrides = {}) {
  const req = { params: {}, query: {}, body: {}, ...overrides };
  const res = {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
  };
  return { req, res };
}

function resetMocks() {
  jest.clearAllMocks();
}

// ─── Tests ──────────────────────────────────────────────────────────────────────

describe('analytics.controller', () => {
  beforeEach(resetMocks);

  // ─── getDashboard ──────────────────────────────────────────────────────────────

  describe('getDashboard', () => {
    it('returns aggregated dashboard data on success', async () => {
      mockAnalyticsService.getPipelineSummary.mockResolvedValue(FIXTURES.pipeline);
      mockAnalyticsService.getHotLeads.mockResolvedValue(FIXTURES.hotLeads);
      mockAnalyticsService.getWeeklySummary.mockResolvedValue(FIXTURES.weeklyStats);
      mockAnalyticsService.getVisitStats.mockResolvedValue(FIXTURES.visitStats);
      mockAnalyticsService.getConversionRates.mockResolvedValue(FIXTURES.conversionRates);
      mockAnalyticsService.getLeadSourceBreakdown.mockResolvedValue(FIXTURES.leadSources);

      const { req, res } = mockReqRes();
      await getDashboard(req, res);

      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: expect.objectContaining({
          pipeline: FIXTURES.pipeline,
          hotLeads: FIXTURES.hotLeads,
          weeklyStats: FIXTURES.weeklyStats,
          visitStats: FIXTURES.visitStats,
          conversionRates: FIXTURES.conversionRates,
          leadSources: FIXTURES.leadSources,
        }),
      }));
    });

    it('calls all 6 analytics service methods in parallel', async () => {
      mockAnalyticsService.getPipelineSummary.mockResolvedValue({});
      mockAnalyticsService.getHotLeads.mockResolvedValue([]);
      mockAnalyticsService.getWeeklySummary.mockResolvedValue({});
      mockAnalyticsService.getVisitStats.mockResolvedValue({});
      mockAnalyticsService.getConversionRates.mockResolvedValue({});
      mockAnalyticsService.getLeadSourceBreakdown.mockResolvedValue({});

      const { req, res } = mockReqRes();
      await getDashboard(req, res);

      expect(mockAnalyticsService.getPipelineSummary).toHaveBeenCalledTimes(1);
      expect(mockAnalyticsService.getHotLeads).toHaveBeenCalledTimes(1);
      expect(mockAnalyticsService.getWeeklySummary).toHaveBeenCalledTimes(1);
      expect(mockAnalyticsService.getVisitStats).toHaveBeenCalledWith('week');
      expect(mockAnalyticsService.getConversionRates).toHaveBeenCalledWith('week');
      expect(mockAnalyticsService.getLeadSourceBreakdown).toHaveBeenCalledTimes(1);
    });

    it('returns 500 with DASHBOARD_ERROR when service throws', async () => {
      mockAnalyticsService.getPipelineSummary.mockRejectedValue(new Error('DB down'));

      const { req, res } = mockReqRes();
      await getDashboard(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'DASHBOARD_ERROR' }),
      }));
    });
  });

  // ─── getPipeline ───────────────────────────────────────────────────────────────

  describe('getPipeline', () => {
    it('returns pipeline summary on success', async () => {
      mockAnalyticsService.getPipelineSummary.mockResolvedValue(FIXTURES.pipeline);

      const { req, res } = mockReqRes();
      await getPipeline(req, res);

      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.pipeline,
      }));
    });

    it('returns 500 with PIPELINE_ERROR when service throws', async () => {
      mockAnalyticsService.getPipelineSummary.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getPipeline(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'PIPELINE_ERROR' }),
      }));
    });
  });

  // ─── getHotLeads ───────────────────────────────────────────────────────────────

  describe('getHotLeads', () => {
    it('returns hot leads on success', async () => {
      mockAnalyticsService.getHotLeads.mockResolvedValue(FIXTURES.hotLeads);

      const { req, res } = mockReqRes();
      await getHotLeads(req, res);

      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.hotLeads,
      }));
    });

    it('returns 500 with HOT_LEADS_ERROR when service throws', async () => {
      mockAnalyticsService.getHotLeads.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getHotLeads(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'HOT_LEADS_ERROR' }),
      }));
    });
  });

  // ─── getVisitStats ─────────────────────────────────────────────────────────────

  describe('getVisitStats', () => {
    it('returns visit stats with query period', async () => {
      mockAnalyticsService.getVisitStats.mockResolvedValue(FIXTURES.visitStats);

      const { req, res } = mockReqRes({ query: { period: 'month' } });
      await getVisitStats(req, res);

      expect(mockAnalyticsService.getVisitStats).toHaveBeenCalledWith('month');
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.visitStats,
      }));
    });

    it('defaults to "week" period when not specified', async () => {
      mockAnalyticsService.getVisitStats.mockResolvedValue(FIXTURES.visitStats);

      const { req, res } = mockReqRes();
      await getVisitStats(req, res);

      expect(mockAnalyticsService.getVisitStats).toHaveBeenCalledWith('week');
    });

    it('returns 500 with VISIT_STATS_ERROR when service throws', async () => {
      mockAnalyticsService.getVisitStats.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getVisitStats(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'VISIT_STATS_ERROR' }),
      }));
    });
  });

  // ─── getConversionRates ────────────────────────────────────────────────────────

  describe('getConversionRates', () => {
    it('returns conversion rates with query period', async () => {
      mockAnalyticsService.getConversionRates.mockResolvedValue(FIXTURES.conversionRates);

      const { req, res } = mockReqRes({ query: { period: 'year' } });
      await getConversionRates(req, res);

      expect(mockAnalyticsService.getConversionRates).toHaveBeenCalledWith('year');
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.conversionRates,
      }));
    });

    it('defaults to "week" period when not specified', async () => {
      mockAnalyticsService.getConversionRates.mockResolvedValue(FIXTURES.conversionRates);

      const { req, res } = mockReqRes();
      await getConversionRates(req, res);

      expect(mockAnalyticsService.getConversionRates).toHaveBeenCalledWith('week');
    });

    it('returns 500 with CONVERSION_ERROR when service throws', async () => {
      mockAnalyticsService.getConversionRates.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getConversionRates(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'CONVERSION_ERROR' }),
      }));
    });
  });

  // ─── getNoShowPatterns ─────────────────────────────────────────────────────────

  describe('getNoShowPatterns', () => {
    it('returns no-show patterns with buildingId filter', async () => {
      mockAnalyticsService.getNoShowPatterns.mockResolvedValue(FIXTURES.noShowPatterns);

      const { req, res } = mockReqRes({ query: { buildingId: 'bldg-1' } });
      await getNoShowPatterns(req, res);

      expect(mockAnalyticsService.getNoShowPatterns).toHaveBeenCalledWith('bldg-1');
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.noShowPatterns,
      }));
    });

    it('passes null when no buildingId specified', async () => {
      mockAnalyticsService.getNoShowPatterns.mockResolvedValue(FIXTURES.noShowPatterns);

      const { req, res } = mockReqRes();
      await getNoShowPatterns(req, res);

      expect(mockAnalyticsService.getNoShowPatterns).toHaveBeenCalledWith(null);
    });

    it('returns 500 with NOSHOW_ERROR when service throws', async () => {
      mockAnalyticsService.getNoShowPatterns.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getNoShowPatterns(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'NOSHOW_ERROR' }),
      }));
    });
  });

  // ─── getBuildingPerformance ────────────────────────────────────────────────────

  describe('getBuildingPerformance', () => {
    it('returns building performance for valid id', async () => {
      mockAnalyticsService.getBuildingPerformance.mockResolvedValue(FIXTURES.buildingPerformance);

      const { req, res } = mockReqRes({ params: { id: 'bldg-1' } });
      await getBuildingPerformance(req, res);

      expect(mockAnalyticsService.getBuildingPerformance).toHaveBeenCalledWith('bldg-1');
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.buildingPerformance,
      }));
    });

    it('returns 400 with VALIDATION_ERROR when id is missing', async () => {
      const { req, res } = mockReqRes({ params: {} });
      await getBuildingPerformance(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }));
    });

    it('returns 500 with BUILDING_PERF_ERROR when service throws', async () => {
      mockAnalyticsService.getBuildingPerformance.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes({ params: { id: 'bldg-1' } });
      await getBuildingPerformance(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'BUILDING_PERF_ERROR' }),
      }));
    });
  });

  // ─── getEmployeePerformance ────────────────────────────────────────────────────

  describe('getEmployeePerformance', () => {
    it('returns employee performance for valid id', async () => {
      mockAnalyticsService.getEmployeePerformance.mockResolvedValue(FIXTURES.employeePerformance);

      const { req, res } = mockReqRes({ params: { id: 'emp-1' } });
      await getEmployeePerformance(req, res);

      expect(mockAnalyticsService.getEmployeePerformance).toHaveBeenCalledWith('emp-1');
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.employeePerformance,
      }));
    });

    it('returns 400 with VALIDATION_ERROR when id is missing', async () => {
      const { req, res } = mockReqRes({ params: {} });
      await getEmployeePerformance(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }));
    });

    it('returns 500 with EMPLOYEE_PERF_ERROR when service throws', async () => {
      mockAnalyticsService.getEmployeePerformance.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes({ params: { id: 'emp-1' } });
      await getEmployeePerformance(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'EMPLOYEE_PERF_ERROR' }),
      }));
    });
  });

  // ─── getWeeklySummary ──────────────────────────────────────────────────────────

  describe('getWeeklySummary', () => {
    it('returns weekly summary on success', async () => {
      mockAnalyticsService.getWeeklySummary.mockResolvedValue(FIXTURES.weeklyStats);

      const { req, res } = mockReqRes();
      await getWeeklySummary(req, res);

      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.weeklyStats,
      }));
    });

    it('returns 500 with WEEKLY_SUMMARY_ERROR when service throws', async () => {
      mockAnalyticsService.getWeeklySummary.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getWeeklySummary(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'WEEKLY_SUMMARY_ERROR' }),
      }));
    });
  });

  // ─── getOccupancyTrend ────────────────────────────────────────────────────────

  describe('getOccupancyTrend', () => {
    it('returns occupancy trend on success', async () => {
      mockAnalyticsService.getOccupancyTrend.mockResolvedValue(FIXTURES.occupancyTrend);

      const { req, res } = mockReqRes();
      await getOccupancyTrend(req, res);

      expect(mockAnalyticsService.getOccupancyTrend).toHaveBeenCalledWith(null);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.occupancyTrend,
      }));
    });

    it('passes buildingId when provided', async () => {
      mockAnalyticsService.getOccupancyTrend.mockResolvedValue(FIXTURES.occupancyTrend);

      const { req, res } = mockReqRes({ query: { buildingId: 'bldg-1' } });
      await getOccupancyTrend(req, res);

      expect(mockAnalyticsService.getOccupancyTrend).toHaveBeenCalledWith('bldg-1');
    });

    it('returns 500 with OCCUPANCY_TREND_ERROR when service throws', async () => {
      mockAnalyticsService.getOccupancyTrend.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getOccupancyTrend(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'OCCUPANCY_TREND_ERROR' }),
      }));
    });
  });

  // ─── getRevenueTrend ──────────────────────────────────────────────────────────

  describe('getRevenueTrend', () => {
    it('returns revenue trend with defaults (12m, null, month)', async () => {
      mockAnalyticsService.getRevenueTrend.mockResolvedValue(FIXTURES.revenueTrend);

      const { req, res } = mockReqRes();
      await getRevenueTrend(req, res);

      expect(mockAnalyticsService.getRevenueTrend).toHaveBeenCalledWith('12m', null, 'month');
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.revenueTrend,
      }));
    });

    it('passes all query params to service', async () => {
      mockAnalyticsService.getRevenueTrend.mockResolvedValue(FIXTURES.revenueTrend);

      const { req, res } = mockReqRes({ query: { period: '90d', buildingId: 'bldg-1', granularity: 'week' } });
      await getRevenueTrend(req, res);

      expect(mockAnalyticsService.getRevenueTrend).toHaveBeenCalledWith('90d', 'bldg-1', 'week');
    });

    it('returns 400 for invalid period', async () => {
      const { req, res } = mockReqRes({ query: { period: 'invalid' } });
      await getRevenueTrend(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }));
    });

    it('returns 400 for invalid granularity', async () => {
      const { req, res } = mockReqRes({ query: { granularity: 'year' } });
      await getRevenueTrend(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }));
    });

    it('returns 500 with REVENUE_TREND_ERROR when service throws', async () => {
      mockAnalyticsService.getRevenueTrend.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getRevenueTrend(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'REVENUE_TREND_ERROR' }),
      }));
    });
  });

  // ─── getLeadFunnel ────────────────────────────────────────────────────────────

  describe('getLeadFunnel', () => {
    it('returns lead funnel with defaults (90d, null, week)', async () => {
      mockAnalyticsService.getLeadFunnel.mockResolvedValue(FIXTURES.leadFunnel);

      const { req, res } = mockReqRes();
      await getLeadFunnel(req, res);

      expect(mockAnalyticsService.getLeadFunnel).toHaveBeenCalledWith('90d', null, 'week');
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.leadFunnel,
      }));
    });

    it('passes all query params to service', async () => {
      mockAnalyticsService.getLeadFunnel.mockResolvedValue(FIXTURES.leadFunnel);

      const { req, res } = mockReqRes({ query: { period: '30d', buildingId: 'bldg-2', granularity: 'day' } });
      await getLeadFunnel(req, res);

      expect(mockAnalyticsService.getLeadFunnel).toHaveBeenCalledWith('30d', 'bldg-2', 'day');
    });

    it('returns 400 for invalid period', async () => {
      const { req, res } = mockReqRes({ query: { period: '1y' } });
      await getLeadFunnel(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }));
    });

    it('returns 400 for invalid granularity', async () => {
      const { req, res } = mockReqRes({ query: { granularity: 'quarter' } });
      await getLeadFunnel(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }));
    });

    it('returns 500 with LEAD_FUNNEL_ERROR when service throws', async () => {
      mockAnalyticsService.getLeadFunnel.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getLeadFunnel(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'LEAD_FUNNEL_ERROR' }),
      }));
    });
  });

  // ─── getVisitMetrics ──────────────────────────────────────────────────────────

  describe('getVisitMetrics', () => {
    it('returns visit metrics with defaults (30d, null, week)', async () => {
      mockAnalyticsService.getVisitMetrics.mockResolvedValue(FIXTURES.visitMetrics);

      const { req, res } = mockReqRes();
      await getVisitMetrics(req, res);

      expect(mockAnalyticsService.getVisitMetrics).toHaveBeenCalledWith('30d', null, 'week');
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: true,
        data: FIXTURES.visitMetrics,
      }));
    });

    it('passes all query params to service', async () => {
      mockAnalyticsService.getVisitMetrics.mockResolvedValue(FIXTURES.visitMetrics);

      const { req, res } = mockReqRes({ query: { period: '90d', buildingId: 'bldg-1', granularity: 'month' } });
      await getVisitMetrics(req, res);

      expect(mockAnalyticsService.getVisitMetrics).toHaveBeenCalledWith('90d', 'bldg-1', 'month');
    });

    it('returns 400 for invalid period', async () => {
      const { req, res } = mockReqRes({ query: { period: '6m' } });
      await getVisitMetrics(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }));
    });

    it('returns 400 for invalid granularity', async () => {
      const { req, res } = mockReqRes({ query: { granularity: 'hour' } });
      await getVisitMetrics(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }));
    });

    it('returns 500 with VISIT_METRICS_ERROR when service throws', async () => {
      mockAnalyticsService.getVisitMetrics.mockRejectedValue(new Error('fail'));

      const { req, res } = mockReqRes();
      await getVisitMetrics(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
        error: expect.objectContaining({ code: 'VISIT_METRICS_ERROR' }),
      }));
    });
  });
});
