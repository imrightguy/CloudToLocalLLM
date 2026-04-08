// ─── Analytics Service — Phase 4 ───
const { db } = require('../database/connection');
const {
  leadsTable, visitsTable, buildingsTable, employeesTable, usersTable,
} = require('../database/schema');
const { sql, eq, and, gte, lte, count, desc } = require('drizzle-orm');

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
    console.error('[analytics.service] getHotLeads error:', error);
    throw error;
  }
}

// ─── Pipeline Summary ───

async function getPipelineSummary() {
  try {
    const stages = [
      // User-facing stages (Flutter frontend)
      'nouveau', 'contacte', 'qualifie', 'visitePlanifiee', 'visite_planifiee',
      'offreEnvoyee', 'negociation', 'bailSigne', 'signe',
      // Internal SMS-flow stages
      'visite_completee', 'interesse', 'inactif',
    ];

    const results = {};
    for (const stage of stages) {
      const [{ total }] = await db
        .select({ total: count() })
        .from(leadsTable)
        .where(eq(leadsTable.stage, stage));
      results[stage] = Number(total);
    }

    return results;
  } catch (error) {
    console.error('[analytics.service] getPipelineSummary error:', error);
    throw error;
  }
}

// ─── Conversion Rates ───

async function getConversionRates(period = 'week') {
  try {
    const periodStart = getPeriodStart(period);

    // Total visits in period
    const [{ total }] = await db
      .select({ total: count() })
      .from(visitsTable)
      .where(gte(visitsTable.createdAt, periodStart));

    // Visits that resulted in 'interesse' outcome
    const [{ converted }] = await db
      .select({ converted: count() })
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
    console.error('[analytics.service] getConversionRates error:', error);
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
        count: count(),
      })
      .from(visitsTable)
      .leftJoin(buildingsTable, eq(visitsTable.buildingId, buildingsTable.id))
      .where(and(...conditions))
      .groupBy(visitsTable.buildingId, buildingsTable.name)
      .orderBy(desc(count()));

    // Grouped by employee
    const byEmployee = await db
      .select({
        employeeId: visitsTable.employeeId,
        employeeName: sql`CONCAT(${employeesTable.firstName}, ' ', ${employeesTable.lastName})`.as('employee_name'),
        count: count(),
      })
      .from(visitsTable)
      .leftJoin(employeesTable, eq(visitsTable.employeeId, employeesTable.id))
      .where(and(...conditions))
      .groupBy(visitsTable.employeeId, employeesTable.firstName, employeesTable.lastName)
      .orderBy(desc(count()));

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
    console.error('[analytics.service] getNoShowPatterns error:', error);
    throw error;
  }
}

// ─── Visit Stats ───

async function getVisitStats(period = 'week') {
  try {
    const periodStart = getPeriodStart(period);

    const [{ total }] = await db
      .select({ total: count() })
      .from(visitsTable)
      .where(gte(visitsTable.createdAt, periodStart));

    const [{ completed }] = await db
      .select({ completed: count() })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'completed'),
        ),
      );

    const [{ cancelled }] = await db
      .select({ cancelled: count() })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'cancelled'),
        ),
      );

    const [{ noShow }] = await db
      .select({ noShow: count() })
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
    console.error('[analytics.service] getVisitStats error:', error);
    throw error;
  }
}

// ─── Lead Source Breakdown ───

async function getLeadSourceBreakdown() {
  try {
    const rows = await db
      .select({
        source: leadsTable.source,
        count: count(),
      })
      .from(leadsTable)
      .groupBy(leadsTable.source)
      .orderBy(desc(count()));

    return rows.map((r) => ({
      source: r.source,
      count: Number(r.count),
    }));
  } catch (error) {
    console.error('[analytics.service] getLeadSourceBreakdown error:', error);
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
      .select({ total: count() })
      .from(visitsTable)
      .innerJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
      .where(eq(unitsTable.buildingId, buildingId));

    // Conversions (outcome = 'interesse')
    const [{ conversions }] = await db
      .select({ conversions: count() })
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
    console.error('[analytics.service] getBuildingPerformance error:', error);
    throw error;
  }
}

// ─── Weekly Summary ───

async function getWeeklySummary() {
  try {
    const periodStart = getPeriodStart('week');

    // New leads this week
    const [{ newLeads }] = await db
      .select({ newLeads: count() })
      .from(leadsTable)
      .where(gte(leadsTable.createdAt, periodStart));

    // Visits completed
    const [{ visitsCompleted }] = await db
      .select({ visitsCompleted: count() })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'completed'),
        ),
      );

    // Conversions (outcome = 'interesse')
    const [{ conversions }] = await db
      .select({ conversions: count() })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.outcome, 'interesse'),
        ),
      );

    // No-shows
    const [{ noShows }] = await db
      .select({ noShows: count() })
      .from(visitsTable)
      .where(
        and(
          gte(visitsTable.createdAt, periodStart),
          eq(visitsTable.status, 'no_show'),
        ),
      );

    // Hot leads count (current hot leads, not just this week)
    const [{ hotLeads }] = await db
      .select({ hotLeads: count() })
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
    console.error('[analytics.service] getWeeklySummary error:', error);
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
      .select({ total: count() })
      .from(visitsTable)
      .where(eq(visitsTable.employeeId, employeeId));

    // Confirmed visits (employee confirmed)
    const [{ confirmed }] = await db
      .select({ confirmed: count() })
      .from(visitsTable)
      .where(
        and(
          eq(visitsTable.employeeId, employeeId),
          eq(visitsTable.employeeConfirmed, true),
        ),
      );

    // No-show visits
    const [{ noShows }] = await db
      .select({ noShows: count() })
      .from(visitsTable)
      .where(
        and(
          eq(visitsTable.employeeId, employeeId),
          eq(visitsTable.status, 'no_show'),
        ),
      );

    // Completed visits
    const [{ completed }] = await db
      .select({ completed: count() })
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
    console.error('[analytics.service] getEmployeePerformance error:', error);
    throw error;
  }
}

module.exports = {
  getHotLeads,
  getPipelineSummary,
  getConversionRates,
  getNoShowPatterns,
  getVisitStats,
  getLeadSourceBreakdown,
  getBuildingPerformance,
  getWeeklySummary,
  getEmployeePerformance,
};
