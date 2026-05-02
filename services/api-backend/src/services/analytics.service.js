const {
  sql, eq, and, gte, desc, or,
} = require('drizzle-orm');
const logger = require('../utils/logger');
const { VALID_LEAD_STAGES } = require('../constants/lead-stages');
const { cache } = require('../utils/cache');
const { db } = require('../database/connection');
const {
  leadsTable, visitsTable, buildingsTable, employeesTable, leasesTable, unitsTable,
  communicationLogsTable, communicationThreadsTable,
} = require('../database/schema');

const VALID_PERIODS = new Set(['30d', '90d', '12m']);
const VALID_GRANULARITIES = new Set(['day', 'week', 'month']);
const OPEN_THREAD_STATES = new Set([
  'message_only',
  'awaiting_employee_confirmation',
  'awaiting_tenant_confirmation',
  'follow_up_required',
]);

// ─── Helpers ───

/**
 * Returns a Date object for the start of the requested period relative to now.
 * period: 'week' | 'month' | 'year'
 */
function getPeriodStart(period = 'week') {
  const now = new Date();
  switch (period) {
    case 'month':
      return new Date(now.getFullYear(), now.getMonth(), 1);
    case 'year':
      return new Date(now.getFullYear(), 0, 1);
    case 'week':
    default: {
      const day = now.getDay();
      const diff = now.getDate() - day + (day === 0 ? -6 : 1); // Monday
      return new Date(now.getFullYear(), now.getMonth(), diff);
    }
  }
}

// ─── Hot Leads ───

async function getHotLeads() {
  try {
    const rows = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.stage, 'interesse'))
      .orderBy(desc(leadsTable.createdAt));

    return rows;
  } catch (error) {
    logger.error('[analytics.service] getHotLeads error:', error);
    throw error;
  }
}

// ─── Pipeline Summary ───

async function getPipelineSummary() {
  try {
    const results = {};
    for (const stage of VALID_LEAD_STAGES) {
      const [{ total }] = await db
        .select({ total: sql`count(*)` })
        .from(leadsTable)
        .where(eq(leadsTable.stage, stage));
      results[stage] = Number(total);
    }

    return results;
  } catch (error) {
    logger.error('[analytics.service] getPipelineSummary error:', error);
    throw error;
  }
}

// ─── Conversion Rates ───

async function getConversionRates(period = 'week') {
  try {
    const periodStart = getPeriodStart(period);

    // Total visits in period
    const [{ total }] = await db
      .select({ total: sql`count(*)` })
      .from(visitsTable)
      .where(gte(visitsTable.createdAt, periodStart));

    // Visits that resulted in 'interesse' outcome
    const [{ converted }] = await db
      .select({ converted: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.outcome, 'interesse'),
        ),
      );

    const rate = Number(total) > 0
      ? Math.round((Number(converted) / Number(total)) * 10000) / 100
      : 0;

    return {
      period,
      totalVisits: Number(total),
      converted: Number(converted),
      conversionRate: `${rate}%`,
    };
  } catch (error) {
    logger.error('[analytics.service] getConversionRates error:', error);
    throw error;
  }
}

// ─── No-Show Patterns ───

async function getNoShowPatterns(buildingId = null) {
  try {
    const conditions = [eq(visitsTable.status, 'no_show')];
    if (buildingId) {
      conditions.push(eq(visitsTable.buildingId, buildingId));
    }

    // Grouped by building
    const byBuilding = await db
      .select({
        buildingId: visitsTable.buildingId,
        buildingName: buildingsTable.name,
        count: sql`count(*)`,
      })
      .from(visitsTable)
      .leftJoin(buildingsTable, eq(visitsTable.buildingId, buildingsTable.id))
      .where(and(...conditions))
      .groupBy(visitsTable.buildingId, buildingsTable.name)
      .orderBy(desc(sql`count(*)`));

    // Grouped by employee
    const byEmployee = await db
      .select({
        employeeId: visitsTable.employeeId,
        employeeName: sql`CONCAT(${employeesTable.firstName}, ' ', ${employeesTable.lastName})`.as('employee_name'),
        count: sql`count(*)`,
      })
      .from(visitsTable)
      .leftJoin(employeesTable, eq(visitsTable.employeeId, employeesTable.id))
      .where(and(...conditions))
      .groupBy(visitsTable.employeeId, employeesTable.firstName, employeesTable.lastName)
      .orderBy(desc(sql`count(*)`));

    return {
      byBuilding: byBuilding.map((r) => ({
        buildingId: r.buildingId,
        buildingName: r.buildingName,
        count: Number(r.count),
      })),
      byEmployee: byEmployee.map((r) => ({
        employeeId: r.employeeId,
        employeeName: r.employeeName,
        count: Number(r.count),
      })),
    };
  } catch (error) {
    logger.error('[analytics.service] getNoShowPatterns error:', error);
    throw error;
  }
}

// ─── Visit Stats ───

async function getVisitStats(period = 'week') {
  try {
    const periodStart = getPeriodStart(period);

    const [{ total }] = await db
      .select({ total: sql`count(*)` })
      .from(visitsTable)
      .where(gte(visitsTable.createdAt, periodStart));

    const [{ completed }] = await db
      .select({ completed: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'completed'),
        ),
      );

    const [{ cancelled }] = await db
      .select({ cancelled: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'cancelled'),
        ),
      );

    const [{ noShow }] = await db
      .select({ noShow: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'no_show'),
        ),
      );

    return {
      period,
      total: Number(total),
      completed: Number(completed),
      cancelled: Number(cancelled),
      noShow: Number(noShow),
    };
  } catch (error) {
    logger.error('[analytics.service] getVisitStats error:', error);
    throw error;
  }
}

// ─── Lead Source Breakdown ───

async function getLeadSourceBreakdown() {
  try {
    const rows = await db
      .select({
        source: leadsTable.source,
        count: sql`count(*)`,
      })
      .from(leadsTable)
      .groupBy(leadsTable.source)
      .orderBy(desc(sql`count(*)`));

    return rows.map((r) => ({
      source: r.source,
      count: Number(r.count),
    }));
  } catch (error) {
    logger.error('[analytics.service] getLeadSourceBreakdown error:', error);
    throw error;
  }
}

// ─── Building Performance ───

async function getBuildingPerformance(buildingId) {
  try {
    if (!buildingId) {
      throw new Error('buildingId is required');
    }

    // Total visits for this building (via unit join or direct buildingId on visits)
    // visitsTable doesn't have a buildingId directly — it has unitId. We join through units.
    // Actually checking schema: visitsTable has no buildingId. We join via unitId → unitsTable → buildingId.
    // But the task says visitsTable has buildingId — let's use a direct join approach.
    // Looking at schema again: visitsTable has unitId, not buildingId directly.
    // We'll join through units to get buildingId.
    const { unitsTable } = require('../database/schema');

    // Total visits
    const [{ total }] = await db
      .select({ total: sql`count(*)` })
      .from(visitsTable)
      .innerJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
      .where(eq(unitsTable.buildingId, buildingId));

    // Conversions (outcome = 'interesse')
    const [{ conversions }] = await db
      .select({ conversions: sql`count(*)` })
      .from(visitsTable)
      .innerJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
      .where(
        and(
          eq(unitsTable.buildingId, buildingId),
          eq(visitsTable.outcome, 'interesse'),
        ),
      );

    // Avg time-to-convert: average difference between lead.createdAt and visit.createdAt
    // for visits with outcome = 'interesse'
    const avgResult = await db
      .select({
        avgDays: sql`AVG(EXTRACT(EPOCH FROM (${visitsTable.createdAt} - ${leadsTable.createdAt})) / 86400)`.as('avg_days'),
      })
      .from(visitsTable)
      .innerJoin(leadsTable, eq(visitsTable.leadId, leadsTable.id))
      .innerJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
      .where(
        and(
          eq(unitsTable.buildingId, buildingId),
          eq(visitsTable.outcome, 'interesse'),
        ),
      );

    // Building info
    const [building] = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, buildingId))
      .limit(1);

    return {
      building: building || null,
      totalVisits: Number(total),
      conversions: Number(conversions),
      conversionRate: Number(total) > 0
        ? `${Math.round((Number(conversions) / Number(total)) * 10000) / 100}%`
        : '0%',
      avgTimeToConvertDays: avgResult.length > 0 && avgResult[0].avgDays !== null
        ? Math.round(Number(avgResult[0].avgDays) * 10) / 10
        : null,
    };
  } catch (error) {
    logger.error('[analytics.service] getBuildingPerformance error:', error);
    throw error;
  }
}

// ─── Weekly Summary ───

async function getWeeklySummary() {
  try {
    const periodStart = getPeriodStart('week');

    // New leads this week
    const [{ newLeads }] = await db
      .select({ newLeads: sql`count(*)` })
      .from(leadsTable)
      .where(gte(leadsTable.createdAt, periodStart));

    // Visits completed
    const [{ visitsCompleted }] = await db
      .select({ visitsCompleted: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'completed'),
        ),
      );

    // Conversions (outcome = 'interesse')
    const [{ conversions }] = await db
      .select({ conversions: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.outcome, 'interesse'),
        ),
      );

    // No-shows
    const [{ noShows }] = await db
      .select({ noShows: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'no_show'),
        ),
      );

    // Hot leads count (current hot leads, not just this week)
    const [{ hotLeads }] = await db
      .select({ hotLeads: sql`count(*)` })
      .from(leadsTable)
      .where(eq(leadsTable.stage, 'interesse'));

    return {
      period: 'week',
      periodStart: periodStart.toISOString(),
      generatedAt: new Date().toISOString(),
      newLeads: Number(newLeads),
      visitsCompleted: Number(visitsCompleted),
      conversions: Number(conversions),
      noShows: Number(noShows),
      hotLeadsCount: Number(hotLeads),
    };
  } catch (error) {
    logger.error('[analytics.service] getWeeklySummary error:', error);
    throw error;
  }
}

async function getInboxToVisitMetrics() {
  try {
    const now = new Date();
    const dailyStart = new Date(now);
    dailyStart.setDate(now.getDate() - 1);
    const weeklyStart = new Date(now);
    weeklyStart.setDate(now.getDate() - 7);

    const [communicationRows, visitRows, threadRows] = await Promise.all([
      db
        .select({
          direction: communicationLogsTable.direction,
          createdAt: communicationLogsTable.createdAt,
        })
        .from(communicationLogsTable)
        .where(and(
          eq(communicationLogsTable.isActive, true),
          gte(communicationLogsTable.createdAt, weeklyStart),
        )),
      db
        .select({
          status: visitsTable.status,
          createdAt: visitsTable.createdAt,
        })
        .from(visitsTable)
        .where(and(
          eq(visitsTable.isActive, true),
          gte(visitsTable.createdAt, weeklyStart),
        )),
      db
        .select({
          coordinationState: communicationThreadsTable.coordinationState,
          lastMessageAt: communicationThreadsTable.lastMessageAt,
          createdAt: communicationThreadsTable.createdAt,
        })
        .from(communicationThreadsTable)
        .where(eq(communicationThreadsTable.isActive, true)),
    ]);

    const buildWindowMetrics = (startDate) => {
      const isInWindow = (date) => date && new Date(date) >= startDate;
      const inboxVolume = communicationRows.filter((row) => row.direction === 'inbound' && isInWindow(row.createdAt)).length;
      const replies = communicationRows.filter((row) => row.direction === 'outbound' && isInWindow(row.createdAt)).length;
      const bookings = visitRows.filter((row) => ['scheduled', 'confirmed', 'in_progress'].includes(row.status) && isInWindow(row.createdAt)).length;
      const completedVisits = visitRows.filter((row) => row.status === 'completed' && isInWindow(row.createdAt)).length;
      const noShows = visitRows.filter((row) => row.status === 'no_show' && isInWindow(row.createdAt)).length;
      const stalledConversations = threadRows.filter((row) => {
        if (!OPEN_THREAD_STATES.has(row.coordinationState)) {
          return false;
        }
        const lastActivity = row.lastMessageAt || row.createdAt;
        return lastActivity && new Date(lastActivity) < startDate;
      }).length;

      return {
        inboxVolume,
        replies,
        bookings,
        completedVisits,
        noShows,
        stalledConversations,
      };
    };

    return {
      generatedAt: now.toISOString(),
      daily: buildWindowMetrics(dailyStart),
      weekly: buildWindowMetrics(weeklyStart),
    };
  } catch (error) {
    logger.error('[analytics.service] getInboxToVisitMetrics error:', error);
    throw error;
  }
}

// ─── Employee Performance ───

async function getEmployeePerformance(employeeId) {
  try {
    if (!employeeId) {
      throw new Error('employeeId is required');
    }

    // Total visits
    const [{ total }] = await db
      .select({ total: sql`count(*)` })
      .from(visitsTable)
      .where(eq(visitsTable.employeeId, employeeId));

    // Confirmed visits (employee confirmed)
    const [{ confirmed }] = await db
      .select({ confirmed: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          eq(visitsTable.employeeId, employeeId),
          eq(visitsTable.employeeConfirmed, true),
        ),
      );

    // No-show visits
    const [{ noShows }] = await db
      .select({ noShows: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          eq(visitsTable.employeeId, employeeId),
          eq(visitsTable.status, 'no_show'),
        ),
      );

    // Completed visits
    const [{ completed }] = await db
      .select({ completed: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          eq(visitsTable.employeeId, employeeId),
          eq(visitsTable.status, 'completed'),
        ),
      );

    // Employee info
    const [employee] = await db
      .select()
      .from(employeesTable)
      .where(eq(employeesTable.id, employeeId))
      .limit(1);

    return {
      employee: employee || null,
      totalVisits: Number(total),
      completed: Number(completed),
      confirmed: Number(confirmed),
      noShows: Number(noShows),
      confirmationRate: Number(total) > 0
        ? `${Math.round((Number(confirmed) / Number(total)) * 10000) / 100}%`
        : '0%',
      noShowRate: Number(total) > 0
        ? `${Math.round((Number(noShows) / Number(total)) * 10000) / 100}%`
        : '0%',
    };
  } catch (error) {
    logger.error('[analytics.service] getEmployeePerformance error:', error);
    throw error;
  }
}

// ─── Occupancy Trend ───

async function getOccupancyTrend(buildingId = null) {
  try {
    const cacheKey = `analytics:getOccupancyTrend:30d:${buildingId || 'all'}:month`;
    const cached = cache.get(cacheKey);
    if (cached) {return cached;}

    const conditions = [];
    if (buildingId) {
      conditions.push(eq(unitsTable.buildingId, buildingId));
    }

    const rows = await db
      .select({
        buildingId: unitsTable.buildingId,
        buildingName: buildingsTable.name,
        status: unitsTable.status,
        count: sql`count(*)`,
      })
      .from(unitsTable)
      .leftJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
      .where(conditions.length > 0 ? and(...conditions) : undefined)
      .groupBy(unitsTable.buildingId, buildingsTable.name, unitsTable.status);

    const buildingMap = {};
    for (const r of rows) {
      const bid = r.buildingId;
      if (!buildingMap[bid]) {
        buildingMap[bid] = { buildingId: bid, buildingName: r.buildingName, occupied: 0, vacant: 0, maintenance: 0 };
      }
      const count = Number(r.count);
      if (r.status === 'occupied') {buildingMap[bid].occupied = count;}
      else if (r.status === 'vacant') {buildingMap[bid].vacant = count;}
      else if (r.status === 'maintenance') {buildingMap[bid].maintenance = count;}
    }

    const result = Object.values(buildingMap).map((b) => {
      const total = b.occupied + b.vacant + b.maintenance;
      return {
        buildingId: b.buildingId,
        buildingName: b.buildingName,
        totalUnits: total,
        occupiedUnits: b.occupied,
        vacantUnits: b.vacant,
        maintenanceUnits: b.maintenance,
        occupancyRate: total > 0 ? b.occupied / total : 0,
      };
    });

    cache.set(cacheKey, result);
    return result;
  } catch (error) {
    logger.error('[analytics.service] getOccupancyTrend error:', error);
    throw error;
  }
}

// ─── Revenue Trend ───

const PERIOD_DAYS = { '30d': 30, '90d': 90, '12m': 365 };
const GRANULARITY_TRUNC = { day: 'day', week: 'week', month: 'month' };

function validateParams(period, granularity) {
  if (!VALID_PERIODS.has(period)) {
    throw new Error(`Invalid period: ${period}. Must be one of: 30d, 90d, 12m`);
  }
  if (!VALID_GRANULARITIES.has(granularity)) {
    throw new Error(`Invalid granularity: ${granularity}. Must be one of: day, week, month`);
  }
}

function getCacheKey(fnName, period, buildingId, granularity) {
  return `analytics:${fnName}:${period}:${buildingId || 'all'}:${granularity}`;
}

async function getRevenueTrend(period = '12m', buildingId = null, granularity = 'month') {
  try {
    validateParams(period, granularity);

    const cacheKey = getCacheKey('getRevenueTrend', period, buildingId, granularity);
    const cached = cache.get(cacheKey);
    if (cached) {return cached;}

    const days = PERIOD_DAYS[period];
    const periodStart = new Date();
    periodStart.setDate(periodStart.getDate() - days);

    const conditions = [
      gte(leasesTable.startDate, periodStart),
      or(
        eq(leasesTable.status, 'active'),
        eq(leasesTable.status, 'renewed'),
      ),
    ];
    if (buildingId) {
      conditions.push(eq(unitsTable.buildingId, buildingId));
    }

    const truncExpr = GRANULARITY_TRUNC[granularity];

    const [byBuilding, totals] = await Promise.all([
      db
        .select({
          date: sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`.as('period'),
          value: sql`SUM(${leasesTable.rentCents}) / 100`.as('revenue'),
          buildingId: unitsTable.buildingId,
          buildingName: buildingsTable.name,
        })
        .from(leasesTable)
        .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
        .leftJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
        .where(and(...conditions))
        .groupBy(
          sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`,
          unitsTable.buildingId,
          buildingsTable.name,
        )
        .orderBy(sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`),
      db
        .select({
          date: sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`.as('period'),
          value: sql`SUM(${leasesTable.rentCents}) / 100`.as('revenue'),
        })
        .from(leasesTable)
        .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
        .where(
          and(
            gte(leasesTable.startDate, periodStart),
            or(
              eq(leasesTable.status, 'active'),
              eq(leasesTable.status, 'renewed'),
            ),
          ),
        )
        .groupBy(sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`)
        .orderBy(sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`),
    ]);

    const data = byBuilding.map((r) => ({
      date: r.date,
      value: Number(r.value),
      buildingId: r.buildingId,
      buildingName: r.buildingName,
    }));

    const totalsMapped = totals.map((r) => ({
      date: r.date,
      value: Number(r.value),
    }));

    const result = { data, totals: totalsMapped };
    cache.set(cacheKey, result);
    return result;
  } catch (error) {
    logger.error('[analytics.service] getRevenueTrend error:', error);
    throw error;
  }
}

// ─── Lead Funnel ───

const SIGNED_STAGES = ['signe', 'bailSigne'];

async function getLeadFunnel(period = '90d', buildingId = null, granularity = 'week') {
  try {
    validateParams(period, granularity);

    const cacheKey = getCacheKey('getLeadFunnel', period, buildingId, granularity);
    const cached = cache.get(cacheKey);
    if (cached) {return cached;}

    const days = PERIOD_DAYS[period];
    const periodStart = new Date();
    periodStart.setDate(periodStart.getDate() - days);

    const conditions = [gte(leadsTable.createdAt, periodStart)];
    if (buildingId) {
      conditions.push(eq(leadsTable.buildingId, buildingId));
    }

    const [stageRows, timeline] = await Promise.all([
      db
        .select({
          stage: leadsTable.stage,
          count: sql`count(*)`,
        })
        .from(leadsTable)
        .where(and(...conditions))
        .groupBy(leadsTable.stage)
        .orderBy(sql`count(*)`),
      db
        .select({
          date: sql`DATE_TRUNC(${GRANULARITY_TRUNC[granularity]}, ${leadsTable.createdAt})`.as('period'),
          stage: leadsTable.stage,
          count: sql`count(*)`,
        })
        .from(leadsTable)
        .where(and(...conditions))
        .groupBy(
          sql`DATE_TRUNC(${GRANULARITY_TRUNC[granularity]}, ${leadsTable.createdAt})`,
          leadsTable.stage,
        )
        .orderBy(sql`DATE_TRUNC(${GRANULARITY_TRUNC[granularity]}, ${leadsTable.createdAt})`),
    ]);

    const stages = stageRows.map((r) => ({
      stage: r.stage,
      count: Number(r.count),
    }));

    const totalLeads = stages.reduce((sum, s) => sum + s.count, 0);
    const signedCount = stages
      .filter((s) => SIGNED_STAGES.includes(s.stage))
      .reduce((sum, s) => sum + s.count, 0);
    const conversionRate = totalLeads > 0
      ? `${(signedCount / totalLeads * 100).toFixed(1)}%`
      : '0.0%';

    const timelineMapped = timeline.map((r) => ({
      date: r.date,
      stage: r.stage,
      count: Number(r.count),
    }));

    const result = { stages, conversionRate, timeline: timelineMapped };
    cache.set(cacheKey, result);
    return result;
  } catch (error) {
    logger.error('[analytics.service] getLeadFunnel error:', error);
    throw error;
  }
}

// ─── Visit Metrics ───

async function getVisitMetrics(period = '30d', buildingId = null, granularity = 'week') {
  try {
    validateParams(period, granularity);

    const cacheKey = getCacheKey('getVisitMetrics', period, buildingId, granularity);
    const cached = cache.get(cacheKey);
    if (cached) {return cached;}

    const days = PERIOD_DAYS[period];
    const periodStart = new Date();
    periodStart.setDate(periodStart.getDate() - days);

    const conditions = [gte(visitsTable.createdAt, periodStart)];
    if (buildingId) {
      conditions.push(eq(unitsTable.buildingId, buildingId));
    }

    const [
      totalResult, completedResult, noShowResult,
      cancelledResult, avgTimeResult, timelineResult,
      lifecycleResult,
    ] = await Promise.all([
      db
        .select({ total: sql`count(*)` })
        .from(visitsTable)
        .where(and(...conditions)),
      db
        .select({ completed: sql`count(*)` })
        .from(visitsTable)
        .where(and(...conditions, eq(visitsTable.status, 'completed'))),
      db
        .select({ noShow: sql`count(*)` })
        .from(visitsTable)
        .where(and(...conditions, eq(visitsTable.status, 'no_show'))),
      db
        .select({ cancelled: sql`count(*)` })
        .from(visitsTable)
        .where(and(...conditions, eq(visitsTable.status, 'cancelled'))),
      db
        .select({
          avgDays: sql`AVG(EXTRACT(EPOCH FROM (${visitsTable.createdAt} - ${leadsTable.createdAt})) / 86400)`.as('avg_days'),
        })
        .from(visitsTable)
        .innerJoin(leadsTable, eq(visitsTable.leadId, leadsTable.id))
        .innerJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
        .where(and(...conditions, eq(visitsTable.status, 'completed'))),
      db
        .select({
          date: sql`DATE_TRUNC(${GRANULARITY_TRUNC[granularity]}, ${visitsTable.createdAt})`.as('period'),
          completed: sql`count(*) FILTER (WHERE ${visitsTable.status} = 'completed')`.as('completed'),
          cancelled: sql`count(*) FILTER (WHERE ${visitsTable.status} = 'cancelled')`.as('cancelled'),
          noShow: sql`count(*) FILTER (WHERE ${visitsTable.status} = 'no_show')`.as('no_show'),
        })
        .from(visitsTable)
        .where(and(...conditions))
        .groupBy(sql`DATE_TRUNC(${GRANULARITY_TRUNC[granularity]}, ${visitsTable.createdAt})`)
        .orderBy(sql`DATE_TRUNC(${GRANULARITY_TRUNC[granularity]}, ${visitsTable.createdAt})`),
      db
        .select({
          tenantConfirmedCount: sql`count(*) FILTER (WHERE ${visitsTable.tenantConfirmed} = true)`.as('tenant_confirmed_count'),
          employeeConfirmedCount: sql`count(*) FILTER (WHERE ${visitsTable.employeeConfirmed} = true)`.as('employee_confirmed_count'),
          rescheduledCount: sql`count(*) FILTER (WHERE ${visitsTable.rescheduledAt} IS NOT NULL)`.as('rescheduled_count'),
          noResponseCancelledCount: sql`count(*) FILTER (WHERE ${visitsTable.reasonCode} = 'no_response')`.as('no_response_cancelled_count'),
          tenantAvgResponseMinutes: sql`AVG(EXTRACT(EPOCH FROM (${visitsTable.tenantConfirmedAt} - ${visitsTable.tenantConfirmationRequestedAt})) / 60)
            FILTER (WHERE ${visitsTable.tenantConfirmedAt} IS NOT NULL AND ${visitsTable.tenantConfirmationRequestedAt} IS NOT NULL)`.as('tenant_avg_response_minutes'),
          employeeAvgResponseMinutes: sql`AVG(EXTRACT(EPOCH FROM (${visitsTable.employeeConfirmedAt} - ${visitsTable.employeeConfirmationRequestedAt})) / 60)
            FILTER (WHERE ${visitsTable.employeeConfirmedAt} IS NOT NULL AND ${visitsTable.employeeConfirmationRequestedAt} IS NOT NULL)`.as('employee_avg_response_minutes'),
          reminder24hQueuedCount: sql`count(*) FILTER (WHERE ${visitsTable.reminder24hQueuedAt} IS NOT NULL)`.as('reminder_24h_queued_count'),
          reminder2hQueuedCount: sql`count(*) FILTER (WHERE ${visitsTable.reminder2hQueuedAt} IS NOT NULL)`.as('reminder_2h_queued_count'),
          morningReminderSentCount: sql`count(*) FILTER (WHERE ${visitsTable.morningReminderSentAt} IS NOT NULL)`.as('morning_reminder_sent_count'),
        })
        .from(visitsTable)
        .where(and(...conditions)),
    ]);

    const totalNum = Number(totalResult[0]?.total || 0);
    const completionRate = totalNum > 0
      ? `${(Number(completedResult[0]?.completed || 0) / totalNum * 100).toFixed(1)}%`
      : '0.0%';
    const noShowRate = totalNum > 0
      ? `${(Number(noShowResult[0]?.noShow || 0) / totalNum * 100).toFixed(1)}%`
      : '0.0%';
    const cancellationRate = totalNum > 0
      ? `${(Number(cancelledResult[0]?.cancelled || 0) / totalNum * 100).toFixed(1)}%`
      : '0.0%';

    const avgTimeToLease = avgTimeResult[0]?.avgDays !== null && avgTimeResult[0]?.avgDays !== undefined
      ? Math.round(Number(avgTimeResult[0].avgDays) * 10) / 10
      : null;

    const timelineMapped = timelineResult.map((r) => ({
      date: r.date,
      completed: Number(r.completed),
      cancelled: Number(r.cancelled),
      noShow: Number(r.noShow),
    }));

    const result = {
      completionRate,
      noShowRate,
      cancellationRate,
      totalVisits: totalNum,
      avgTimeToLease,
      timeline: timelineMapped,
    };
    cache.set(cacheKey, result);
    return result;
  } catch (error) {
    logger.error('[analytics.service] getVisitMetrics error:', error);
    throw error;
  }
}

module.exports = {
  getPeriodStart,
  getHotLeads,
  getPipelineSummary,
  getConversionRates,
  getNoShowPatterns,
  getVisitStats,
  getLeadSourceBreakdown,
  getBuildingPerformance,
  getWeeklySummary,
  getInboxToVisitMetrics,
  getEmployeePerformance,
  getOccupancyTrend,
  getRevenueTrend,
  getLeadFunnel,
  getVisitMetrics,
};
