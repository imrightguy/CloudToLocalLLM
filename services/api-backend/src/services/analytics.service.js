const {
  sql, eq, and, gte, desc,
} = require('drizzle-orm');
const logger = require('../utils/logger');
const { VALID_LEAD_STAGES } = require('../constants/lead-stages');
// ─── Analytics Service — Phase 4 ───
const { db } = require('../database/connection');
const {
  leadsTable, visitsTable, buildingsTable, employeesTable, leasesTable, unitsTable,
} = require('../database/schema');

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
    const conditions = [];
    if (buildingId) {
      conditions.push(eq(buildingsTable.id, buildingId));
    }

    const query = db
      .select({
        buildingId: buildingsTable.id,
        buildingName: buildingsTable.name,
        totalUnits: buildingsTable.totalUnits,
        occupiedUnits: buildingsTable.occupiedUnits,
      })
      .from(buildingsTable)
      .where(conditions.length > 0 ? and(...conditions) : undefined);

    const rows = await query;

    return rows.map((r) => {
      const total = Number(r.totalUnits);
      const occupied = Number(r.occupiedUnits);
      return {
        buildingId: r.buildingId,
        buildingName: r.buildingName,
        totalUnits: total,
        occupiedUnits: occupied,
        vacantUnits: total - occupied,
        occupancyRate: total > 0 ? occupied / total : 0,
      };
    });
  } catch (error) {
    logger.error('[analytics.service] getOccupancyTrend error:', error);
    throw error;
  }
}

// ─── Revenue Trend ───

const PERIOD_DAYS = { '30d': 30, '90d': 90, '12m': 365 };
const GRANULARITY_TRUNC = { day: 'day', week: 'week', month: 'month' };

async function getRevenueTrend(period = '12m', buildingId = null, granularity = 'month') {
  try {
    const days = PERIOD_DAYS[period] || 365;
    const periodStart = new Date();
    periodStart.setDate(periodStart.getDate() - days);

    const conditions = [gte(leasesTable.startDate, periodStart)];
    if (buildingId) {
      conditions.push(eq(unitsTable.buildingId, buildingId));
    }

    const truncExpr = GRANULARITY_TRUNC[granularity] || 'month';

    const rows = await db
      .select({
        date: sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`.as('period'),
        value: sql`SUM(${leasesTable.rentCents})`.as('revenue'),
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
      .orderBy(sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`);

    const data = rows.map((r) => ({
      date: r.date,
      value: Number(r.value),
      buildingId: r.buildingId,
      buildingName: r.buildingName,
    }));

    const totals = await db
      .select({
        date: sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`.as('period'),
        value: sql`SUM(${leasesTable.rentCents})`.as('revenue'),
      })
      .from(leasesTable)
      .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
      .where(and(...conditions.filter((c) => !buildingId)))
      .groupBy(sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`)
      .orderBy(sql`DATE_TRUNC(${truncExpr}, ${leasesTable.startDate})`);

    const totalsMapped = totals.map((r) => ({
      date: r.date,
      value: Number(r.value),
    }));

    return { data, totals: totalsMapped };
  } catch (error) {
    logger.error('[analytics.service] getRevenueTrend error:', error);
    throw error;
  }
}

// ─── Lead Funnel ───

async function getLeadFunnel(period = '90d', buildingId = null, granularity = 'week') {
  try {
    const days = PERIOD_DAYS[period] || 90;
    const periodStart = new Date();
    periodStart.setDate(periodStart.getDate() - days);

    const conditions = [gte(leadsTable.createdAt, periodStart)];
    if (buildingId) {
      conditions.push(eq(leadsTable.buildingId, buildingId));
    }

    const stageRows = await db
      .select({
        stage: leadsTable.stage,
        count: sql`count(*)`,
      })
      .from(leadsTable)
      .where(and(...conditions))
      .groupBy(leadsTable.stage)
      .orderBy(sql`count(*)`);

    const stages = stageRows.map((r) => ({
      stage: r.stage,
      count: Number(r.count),
    }));

    const totalLeads = stages.reduce((sum, s) => sum + s.count, 0);
    const interestedCount = stages.find((s) => s.stage === 'interesse')?.count || 0;
    const conversionRate = totalLeads > 0
      ? `${(interestedCount / totalLeads * 100).toFixed(1)}%`
      : '0.0%';

    const truncExpr = GRANULARITY_TRUNC[granularity] || 'week';

    const timeline = await db
      .select({
        date: sql`DATE_TRUNC(${truncExpr}, ${leadsTable.createdAt})`.as('period'),
        stage: leadsTable.stage,
        count: sql`count(*)`,
      })
      .from(leadsTable)
      .where(and(...conditions))
      .groupBy(
        sql`DATE_TRUNC(${truncExpr}, ${leadsTable.createdAt})`,
        leadsTable.stage,
      )
      .orderBy(
        sql`DATE_TRUNC(${truncExpr}, ${leadsTable.createdAt})`,
      );

    const timelineMapped = timeline.map((r) => ({
      date: r.date,
      stage: r.stage,
      count: Number(r.count),
    }));

    return { stages, conversionRate, timeline: timelineMapped };
  } catch (error) {
    logger.error('[analytics.service] getLeadFunnel error:', error);
    throw error;
  }
}

// ─── Visit Metrics ───

async function getVisitMetrics(period = '30d', buildingId = null, granularity = 'week') {
  try {
    const days = PERIOD_DAYS[period] || 30;
    const periodStart = new Date();
    periodStart.setDate(periodStart.getDate() - days);

    const conditions = [gte(visitsTable.createdAt, periodStart)];
    if (buildingId) {
      conditions.push(eq(unitsTable.buildingId, buildingId));
    }

    const [{ total }] = await db
      .select({ total: sql`count(*)` })
      .from(visitsTable)
      .where(and(...conditions));

    const [{ completed }] = await db
      .select({ completed: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          ...conditions,
          eq(visitsTable.status, 'completed'),
        ),
      );

    const [{ noShow }] = await db
      .select({ noShow: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          ...conditions,
          eq(visitsTable.status, 'no_show'),
        ),
      );

    const [{ cancelled }] = await db
      .select({ cancelled: sql`count(*)` })
      .from(visitsTable)
      .where(
        and(
          ...conditions,
          eq(visitsTable.status, 'cancelled'),
        ),
      );

    const totalNum = Number(total);
    const completionRate = totalNum > 0
      ? `${(Number(completed) / totalNum * 100).toFixed(1)}%`
      : '0.0%';
    const noShowRate = totalNum > 0
      ? `${(Number(noShow) / totalNum * 100).toFixed(1)}%`
      : '0.0%';

    const truncExpr = GRANULARITY_TRUNC[granularity] || 'week';

    const timeline = await db
      .select({
        date: sql`DATE_TRUNC(${truncExpr}, ${visitsTable.createdAt})`.as('period'),
        completed: sql`count(*) FILTER (WHERE ${visitsTable.status} = 'completed')`.as('completed'),
        cancelled: sql`count(*) FILTER (WHERE ${visitsTable.status} = 'cancelled')`.as('cancelled'),
        noShow: sql`count(*) FILTER (WHERE ${visitsTable.status} = 'no_show')`.as('no_show'),
      })
      .from(visitsTable)
      .where(and(...conditions))
      .groupBy(sql`DATE_TRUNC(${truncExpr}, ${visitsTable.createdAt})`)
      .orderBy(sql`DATE_TRUNC(${truncExpr}, ${visitsTable.createdAt})`);

    const timelineMapped = timeline.map((r) => ({
      date: r.date,
      completed: Number(r.completed),
      cancelled: Number(r.cancelled),
      noShow: Number(r.noShow),
    }));

    return {
      completionRate,
      noShowRate,
      totalVisits: totalNum,
      timeline: timelineMapped,
    };
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
  getEmployeePerformance,
  getOccupancyTrend,
  getRevenueTrend,
  getLeadFunnel,
  getVisitMetrics,
};
