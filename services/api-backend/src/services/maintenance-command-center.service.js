const {
  eq,
  and,
  asc,
  desc,
  inArray,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  buildingsTable,
  unitsTable,
  renovationsTable,
  renovationTasksTable,
  renovationOrdersTable,
  workerIntakeRecordsTable,
  employeesTable,
  employeeAssignmentsTable,
  employeeSchedulesTable,
  smsLogsTable,
} = require('../database/schema');

const OPEN_TASK_STATUSES = new Set(['todo', 'in_progress', 'blocked']);
const OPEN_ORDER_STATUSES = new Set(['draft', 'ordered', 'partially_received']);
const OPEN_INTAKE_STATUSES = new Set(['new', 'triaged', 'linked']);
const READY_RENOVATION_STATES = new Set(['ready_to_list', 'ready_for_leasing', 'ready']);
const DAY_MS = 24 * 60 * 60 * 1000;

const toDate = (value) => {
  if (!value) {
    return null;
  }
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const toIso = (value) => {
  const date = toDate(value);
  return date ? date.toISOString() : null;
};

const normalizePhone = (value) => {
  if (!value) {
    return null;
  }
  const digits = String(value).replace(/\D/g, '');
  if (!digits) {
    return null;
  }
  return digits.startsWith('1') && digits.length === 11 ? digits.slice(1) : digits;
};

const formatMaintenanceDay = (dayOfWeek) => {
  const labels = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  return labels[dayOfWeek] || `Jour ${dayOfWeek}`;
};

const deriveFitLabel = (score) => {
  if (score >= 85) return 'Excellent';
  if (score >= 60) return 'Bon';
  if (score >= 35) return 'Partiel';
  return 'Faible';
};

const deriveLoadLabel = (openTaskCount) => {
  if (openTaskCount === 0) return 'Libre';
  if (openTaskCount <= 2) return 'Léger';
  if (openTaskCount <= 4) return 'Modéré';
  return 'Chargé';
};

const sortBacklogRows = (rows) => rows.sort((left, right) => {
  const score = (row) => {
    if (row.phase === 'blocked') { return 0; }
    if (row.overdueTaskCount > 0) { return 1; }
    if (row.dueSoonTaskCount > 0) { return 2; }
    if (row.phase === 'active') { return 3; }
    return 4;
  };

  const leftScore = score(left);
  const rightScore = score(right);
  if (leftScore !== rightScore) {
    return leftScore - rightScore;
  }

  const leftDue = left.nextDueAt ? new Date(left.nextDueAt).getTime() : Number.POSITIVE_INFINITY;
  const rightDue = right.nextDueAt ? new Date(right.nextDueAt).getTime() : Number.POSITIVE_INFINITY;
  if (leftDue !== rightDue) {
    return leftDue - rightDue;
  }

  const leftUpdated = left.updatedAt ? new Date(left.updatedAt).getTime() : 0;
  const rightUpdated = right.updatedAt ? new Date(right.updatedAt).getTime() : 0;
  if (leftUpdated !== rightUpdated) {
    return rightUpdated - leftUpdated;
  }

  return left.unitLabel.localeCompare(right.unitLabel);
});

const buildBacklogRow = ({
  record,
  unit,
  building,
  tasks,
  orders,
  intakes,
  employeeMap,
  tenantMessageMap,
  now,
  sevenDaysFromNow,
}) => {
  const recordTasks = tasks
    .filter((task) => task.renovationRecordId === record.id && task.isActive !== false)
    .sort((left, right) => {
      const leftDate = toDate(left.dueDate)?.getTime() ?? Number.POSITIVE_INFINITY;
      const rightDate = toDate(right.dueDate)?.getTime() ?? Number.POSITIVE_INFINITY;
      if (leftDate !== rightDate) {
        return leftDate - rightDate;
      }
      return toIso(left.createdAt)?.localeCompare(toIso(right.createdAt) ?? '') || left.title.localeCompare(right.title);
    });

  const recordOrders = orders.filter((order) => order.renovationRecordId === record.id && order.isActive !== false);
  const recordIntakes = intakes.filter((intake) => intake.renovationRecordId === record.id && intake.isActive !== false);

  const openTasks = recordTasks.filter((task) => OPEN_TASK_STATUSES.has(task.status));
  const doneTasks = recordTasks.filter((task) => task.status === 'done');
  const blockedTasks = recordTasks.filter((task) => task.status === 'blocked');
  const openOrders = recordOrders.filter((order) => OPEN_ORDER_STATUSES.has(order.status));
  const blockedIntakes = recordIntakes.filter((intake) => OPEN_INTAKE_STATUSES.has(intake.status) && intake.messageKind !== 'general_note');
  const blockedOrders = openOrders.filter((order) => order.status === 'partially_received');

  const assignedEmployeeNames = Array.from(new Set(openTasks
    .map((task) => task.assigneeEmployeeId ? employeeMap.get(task.assigneeEmployeeId) : null)
    .filter(Boolean)));

  const dueCandidates = [record.targetEndDate, ...openTasks.map((task) => task.dueDate), ...openOrders.map((order) => order.expectedAt)]
    .map((value) => toDate(value))
    .filter(Boolean)
    .sort((left, right) => left.getTime() - right.getTime());
  const nextDueDate = dueCandidates[0] || null;
  const overdueTaskCount = openTasks.filter((task) => {
    const dueDate = toDate(task.dueDate);
    return dueDate && dueDate.getTime() < now.getTime();
  }).length;
  const dueSoonTaskCount = openTasks.filter((task) => {
    const dueDate = toDate(task.dueDate);
    if (!dueDate) {
      return false;
    }
    const dueTime = dueDate.getTime();
    return dueTime >= now.getTime() && dueTime <= sevenDaysFromNow.getTime();
  }).length;

  let phase = 'active';
  if (READY_RENOVATION_STATES.has(record.readinessState)) {
    phase = 'ready';
  } else if (record.status === 'blocked' || blockedTasks.length || blockedIntakes.length || blockedOrders.length) {
    phase = 'blocked';
  }

  const blockerNote = blockedIntakes[0]?.summary
    || blockedIntakes[0]?.messageBody
    || blockedTasks[0]?.title
    || (blockedOrders[0] ? `${blockedOrders[0].itemName} en attente` : '')
    || (record.notes || '');

  const nextStep = blockedTasks[0]?.title
    || blockedIntakes[0]?.summary
    || openTasks[0]?.title
    || (openOrders[0] ? `${openOrders[0].itemName} à suivre` : '')
    || (phase === 'ready' ? 'Transmettre la readiness au module Leasing' : 'Poursuivre la remise en état');

  const taskCount = recordTasks.length;
  const doneCount = doneTasks.length;
  const blockerCount = blockedTasks.length + blockedIntakes.length + blockedOrders.length;
  const readiness = !taskCount
    ? '0 % prêt'
    : phase === 'ready'
      ? 'Prêt pour Leasing'
      : `${Math.round((doneCount / taskCount) * 100)} % prêt`;

  const tenantPhoneKey = normalizePhone(unit?.tenantPhone);
  const tenantMessage = tenantPhoneKey ? tenantMessageMap.get(tenantPhoneKey) || null : null;

  return {
    id: record.id,
    unitId: record.unitId,
    buildingId: record.buildingId,
    unitLabel: unit?.label || '—',
    buildingName: building?.name || '—',
    phase,
    readiness,
    taskCount,
    doneCount,
    blockerCount,
    overdueTaskCount,
    dueSoonTaskCount,
    nextStep,
    updatedAt: toIso(record.updatedAt),
    blockerNote,
    nextDueAt: toIso(nextDueDate),
    assignedEmployeeLabel: assignedEmployeeNames.length <= 2 ? assignedEmployeeNames.join(' · ') : `${assignedEmployeeNames.length} assignés`,
    assignedEmployeeNames,
    tenantPhone: unit?.tenantPhone || null,
    tenantMessageStatus: tenantMessage
      ? {
        status: tenantMessage.status,
        lastSentAt: toIso(tenantMessage.createdAt),
        phoneNumber: tenantMessage.phoneNumber,
        errorMessage: tenantMessage.errorMessage || null,
      }
      : {
        status: unit?.tenantPhone ? 'not_sent' : 'unavailable',
        lastSentAt: null,
        phoneNumber: unit?.tenantPhone || null,
        errorMessage: null,
      },
    tasks: recordTasks.map((task) => ({
      title: task.title,
      status: task.status,
      dueDate: toIso(task.dueDate),
      assigneeName: task.assigneeEmployeeId ? employeeMap.get(task.assigneeEmployeeId) || null : null,
    })),
    orders: recordOrders.map((order) => ({
      id: order.id,
      itemName: order.itemName,
      status: order.status,
      expectedAt: toIso(order.expectedAt),
    })),
    intakes: recordIntakes.map((intake) => ({
      id: intake.id,
      messageKind: intake.messageKind,
      status: intake.status,
      summary: intake.summary || intake.messageBody,
      receivedAt: toIso(intake.receivedAt),
    })),
  };
};

const buildReviewQueue = ({ backlog, properties, asOf }) => {
  const recommendations = [];

  for (const row of backlog) {
    if (row.phase === 'blocked' || row.overdueTaskCount > 0) {
      recommendations.push({
        id: `review-${row.id}-blocker`,
        severity: 'urgent',
        kind: 'blocker_follow_up',
        title: `Bloqueur maintenance: ${row.unitLabel}`,
        summary: row.blockerNote || row.nextStep,
        buildingId: row.buildingId,
        buildingName: row.buildingName,
        unitId: row.unitId,
        unitLabel: row.unitLabel,
        renovationId: row.id,
        nextDueAt: row.nextDueAt,
        suggestedAction: 'Ouvrir un suivi humain avant toute relance automatique',
      });
    } else if (row.dueSoonTaskCount > 0) {
      recommendations.push({
        id: `review-${row.id}-due-soon`,
        severity: 'warning',
        kind: 'due_soon_review',
        title: `Suivi proche échéance: ${row.unitLabel}`,
        summary: row.nextStep,
        buildingId: row.buildingId,
        buildingName: row.buildingName,
        unitId: row.unitId,
        unitLabel: row.unitLabel,
        renovationId: row.id,
        nextDueAt: row.nextDueAt,
        suggestedAction: 'Vérifier la capacité et confirmer les prochaines tâches',
      });
    }

    if (row.tenantPhone && ['not_sent', 'unavailable'].indexOf(row.tenantMessageStatus.status) !== -1) {
      recommendations.push({
        id: `review-${row.id}-tenant-draft`,
        severity: 'info',
        kind: 'tenant_sms_draft',
        title: `Brouillon SMS locataire: ${row.unitLabel}`,
        summary: `Préparer un brouillon seulement pour ${row.buildingName} ${row.unitLabel}.`,
        buildingId: row.buildingId,
        buildingName: row.buildingName,
        unitId: row.unitId,
        unitLabel: row.unitLabel,
        renovationId: row.id,
        nextDueAt: row.nextDueAt,
        suggestedAction: 'Conserver en brouillon et demander validation humaine',
        draftSms: `Bonjour, suivi de maintenance pour l'unité ${row.unitLabel} à ${row.buildingName}. Merci de confirmer l'état actuel avant toute relance.`,
      });
    }
  }

  for (const property of properties) {
    if (property.capacity.candidateCount > 0 && property.capacity.dispatchableCount < property.capacity.candidateCount) {
      recommendations.push({
        id: `review-${property.buildingId}-capacity-gap`,
        severity: 'warning',
        kind: 'capacity_gap',
        title: `Capacité sous tension: ${property.buildingName}`,
        summary: `${property.capacity.dispatchableCount} agent(s) disponible(s) sur ${property.capacity.candidateCount} candidat(s).`,
        buildingId: property.buildingId,
        buildingName: property.buildingName,
        unitId: null,
        unitLabel: null,
        renovationId: null,
        nextDueAt: property.nextDueAt,
        suggestedAction: 'Réviser la répartition ou libérer des créneaux',
      });
    }
  }

  const severityRank = { urgent: 0, warning: 1, info: 2 };
  recommendations.sort((left, right) => severityRank[left.severity] - severityRank[right.severity] || left.title.localeCompare(right.title));

  return {
    summary: {
      totalRecommendations: recommendations.length,
      urgentCount: recommendations.filter((item) => item.severity === 'urgent').length,
      warningCount: recommendations.filter((item) => item.severity === 'warning').length,
      infoCount: recommendations.filter((item) => item.severity === 'info').length,
      draftSmsCount: recommendations.filter((item) => item.kind === 'tenant_sms_draft').length,
    },
    recommendations,
    asOf: toIso(asOf),
  };
};

const buildCapacityForBuilding = ({
  building,
  date,
  candidateRows,
  scheduleRows,
  taskRows,
}) => {
  const jsDay = date.getUTCDay();
  const dayOfWeek = jsDay === 0 ? 6 : jsDay - 1;

  const candidateMap = new Map();
  for (const candidate of candidateRows) {
    candidateMap.set(candidate.employeeId, {
      employee: {
        id: candidate.employeeId,
        firstName: candidate.firstName,
        lastName: candidate.lastName,
        email: candidate.email,
        phone: candidate.phone,
        isActive: candidate.isActive,
      },
      assignments: [{
        id: candidate.assignmentId,
        buildingId: building.id,
        buildingName: building.name,
        role: candidate.assignmentRole,
      }],
      schedules: [],
      tasks: [],
      openTaskCount: 0,
      buildingTaskCount: 0,
      fitScore: 0,
      fitLabel: 'Faible',
      loadLabel: 'Libre',
      canDispatch: false,
      reasons: [],
    });
  }

  for (const schedule of scheduleRows) {
    const candidate = candidateMap.get(schedule.employeeId);
    if (!candidate) {
      continue;
    }
    candidate.schedules.push({
      id: schedule.scheduleId,
      buildingId: schedule.buildingId,
      buildingName: schedule.buildingName,
      dayOfWeek: schedule.dayOfWeek,
      dayLabel: formatMaintenanceDay(schedule.dayOfWeek),
      startTime: schedule.startTime,
      endTime: schedule.endTime,
    });
  }

  for (const task of taskRows) {
    const candidate = candidateMap.get(task.assigneeEmployeeId);
    if (!candidate) {
      continue;
    }
    candidate.tasks.push({
      id: task.taskId,
      title: task.title,
      status: task.status,
      buildingId: task.buildingId,
      buildingName: task.buildingName,
    });
    candidate.openTaskCount += 1;
    if (task.buildingId === building.id) {
      candidate.buildingTaskCount += 1;
    }
  }

  const candidates = candidateRows.map((candidate) => {
    const entry = candidateMap.get(candidate.employeeId);
    const hasBuildingAssignment = entry.assignments.length > 0;
    const hasSchedule = entry.schedules.length > 0;

    let fitScore = 0;
    const reasons = [];

    if (hasBuildingAssignment) {
      fitScore += 50;
      reasons.push(`Assigné à ${building.name}`);
    } else {
      reasons.push('Pas d’assignation sur l’immeuble');
    }

    if (hasSchedule) {
      fitScore += 35;
      reasons.push(`Disponible le ${formatMaintenanceDay(dayOfWeek)}`);
    } else {
      reasons.push('Aucun horaire sur ce jour');
    }

    if (entry.openTaskCount === 0) {
      fitScore += 15;
      reasons.push('Aucune tâche en cours');
    } else if (entry.openTaskCount <= 2) {
      fitScore += 10;
      reasons.push(`${entry.openTaskCount} tâche(s) active(s)`);
    } else if (entry.openTaskCount <= 4) {
      fitScore += 5;
      reasons.push(`${entry.openTaskCount} tâches actives`);
    } else {
      reasons.push(`${entry.openTaskCount} tâches actives`);
    }

    const canDispatch = hasBuildingAssignment && hasSchedule && entry.openTaskCount <= 4;

    return {
      ...entry,
      fitScore,
      fitLabel: deriveFitLabel(fitScore),
      loadLabel: deriveLoadLabel(entry.openTaskCount),
      canDispatch,
      reasons,
    };
  }).sort((a, b) => b.fitScore - a.fitScore || a.openTaskCount - b.openTaskCount || a.employee.lastName.localeCompare(b.employee.lastName));

  return {
    buildingId: building.id,
    buildingName: building.name,
    dayOfWeek,
    dayLabel: formatMaintenanceDay(dayOfWeek),
    candidateCount: candidates.length,
    dispatchableCount: candidates.filter((candidate) => candidate.canDispatch).length,
    totalOpenTasks: taskRows.length,
    buildingOpenTasks: taskRows.filter((task) => task.buildingId === building.id).length,
    candidates,
  };
};

const getMaintenanceCommandCenter = async ({ buildingId = null, limit = 12, asOf = new Date() } = {}) => {
  const safeLimit = Math.min(50, Math.max(1, parseInt(limit, 10) || 12));
  const now = asOf instanceof Date ? asOf : new Date(asOf);
  const effectiveNow = Number.isNaN(now.getTime()) ? new Date() : now;
  const dayWindowEnd = new Date(effectiveNow.getTime() + (7 * DAY_MS));

  const [buildings, units, renovations, tasks, orders, intakes, employees, assignments, schedules] = await Promise.all([
    db.select().from(buildingsTable).where(eq(buildingsTable.isActive, true)).orderBy(asc(buildingsTable.name)),
    db.select().from(unitsTable).where(eq(unitsTable.isActive, true)),
    db.select().from(renovationsTable).where(eq(renovationsTable.isActive, true)).orderBy(desc(renovationsTable.updatedAt)),
    db.select().from(renovationTasksTable).where(eq(renovationTasksTable.isActive, true)).orderBy(desc(renovationTasksTable.createdAt)),
    db.select().from(renovationOrdersTable).where(eq(renovationOrdersTable.isActive, true)).orderBy(desc(renovationOrdersTable.createdAt)),
    db.select().from(workerIntakeRecordsTable).where(eq(workerIntakeRecordsTable.isActive, true)).orderBy(desc(workerIntakeRecordsTable.receivedAt)),
    db.select().from(employeesTable).where(eq(employeesTable.isActive, true)),
    db.select().from(employeeAssignmentsTable).where(eq(employeeAssignmentsTable.isActive, true)),
    db.select().from(employeeSchedulesTable).where(eq(employeeSchedulesTable.isActive, true)),
  ]);

  const unitMap = new Map(units.map((unit) => [unit.id, unit]));
  const buildingMap = new Map(buildings.map((building) => [building.id, building]));
  const employeeMap = new Map(employees.map((employee) => [employee.id, `${employee.firstName} ${employee.lastName}`.trim()]));

  const tenantPhoneLookups = Array.from(new Set(units.flatMap((unit) => {
    const normalized = normalizePhone(unit.tenantPhone);
    if (!normalized) {
      return [];
    }
    return [
      unit.tenantPhone,
      normalized,
      normalized.length === 10 ? `+1${normalized}` : `+${normalized}`,
    ];
  })));

  const smsLogs = tenantPhoneLookups.length > 0
    ? await db.select().from(smsLogsTable).where(and(
      eq(smsLogsTable.isActive, true),
      eq(smsLogsTable.direction, 'outbound'),
      inArray(smsLogsTable.phoneNumber, tenantPhoneLookups),
    )).orderBy(desc(smsLogsTable.createdAt))
    : [];

  const tenantMessageMap = new Map();
  for (const smsLog of smsLogs) {
    const phoneKey = normalizePhone(smsLog.phoneNumber);
    if (!phoneKey || tenantMessageMap.has(phoneKey)) {
      continue;
    }
    tenantMessageMap.set(phoneKey, smsLog);
  }

  const activeRenovations = buildingId
    ? renovations.filter((record) => record.buildingId === buildingId)
    : renovations;

  const backlogRows = activeRenovations.map((record) => buildBacklogRow({
    record,
    unit: unitMap.get(record.unitId),
    building: buildingMap.get(record.buildingId),
    tasks,
    orders,
    intakes,
    employeeMap,
    tenantMessageMap,
    now: effectiveNow,
    sevenDaysFromNow: dayWindowEnd,
  }));

  const sortedBacklog = sortBacklogRows(backlogRows);

  const activeBuildingIds = buildingId ? [buildingId] : buildings.map((building) => building.id);
  const properties = activeBuildingIds.map((id) => {
    const building = buildingMap.get(id);
    const buildingRenovations = sortedBacklog.filter((row) => row.buildingId === id);
    const buildingUnitIds = units.filter((unit) => unit.buildingId === id).map((unit) => unit.id);
    const buildingTenantPhones = units
      .filter((unit) => unit.buildingId === id)
      .map((unit) => normalizePhone(unit.tenantPhone))
      .filter(Boolean);
    const buildingSmsLogs = smsLogs.filter((smsLog) => buildingTenantPhones.includes(normalizePhone(smsLog.phoneNumber)));
    const candidateRows = assignments
      .filter((assignment) => assignment.buildingId === id)
      .map((assignment) => {
        const employee = employees.find((entry) => entry.id === assignment.employeeId);
        if (!employee) {
          return null;
        }
        return {
          employeeId: employee.id,
          firstName: employee.firstName,
          lastName: employee.lastName,
          email: employee.email,
          phone: employee.phone,
          isActive: employee.isActive,
          assignmentId: assignment.id,
          assignmentRole: assignment.role,
        };
      })
      .filter(Boolean);

    const candidateIds = candidateRows.map((candidate) => candidate.employeeId);
    const scheduleRows = schedules.filter((schedule) => candidateIds.includes(schedule.employeeId) && schedule.buildingId === id);
    const taskRows = candidateIds.length === 0
      ? []
      : tasks.filter((task) => candidateIds.includes(task.assigneeEmployeeId) && task.status !== 'done' && task.status !== 'cancelled');

    const capacity = building
      ? buildCapacityForBuilding({
        building,
        date: effectiveNow,
        candidateRows,
        scheduleRows,
        taskRows,
      })
      : {
        buildingId: id,
        buildingName: '—',
        dayOfWeek: effectiveNow.getUTCDay(),
        dayLabel: formatMaintenanceDay(effectiveNow.getUTCDay() === 0 ? 6 : effectiveNow.getUTCDay() - 1),
        candidateCount: 0,
        dispatchableCount: 0,
        totalOpenTasks: 0,
        buildingOpenTasks: 0,
        candidates: [],
      };

    const tenantMessageStats = {
      total: buildingSmsLogs.length,
      sent: buildingSmsLogs.filter((smsLog) => smsLog.status === 'sent').length,
      failed: buildingSmsLogs.filter((smsLog) => smsLog.status === 'failed').length,
      latestAt: buildingSmsLogs[0] ? toIso(buildingSmsLogs[0].createdAt) : null,
    };

    const nextDueAt = buildingRenovations[0]?.nextDueAt || null;

    return {
      buildingId: id,
      buildingName: building?.name || '—',
      unitCount: buildingUnitIds.length,
      renovationCount: buildingRenovations.length,
      blockedCount: buildingRenovations.filter((row) => row.phase === 'blocked').length,
      readyCount: buildingRenovations.filter((row) => row.phase === 'ready').length,
      overdueTaskCount: buildingRenovations.reduce((sum, row) => sum + row.overdueTaskCount, 0),
      dueSoonTaskCount: buildingRenovations.reduce((sum, row) => sum + row.dueSoonTaskCount, 0),
      openOrderCount: buildingRenovations.reduce((sum, row) => sum + row.orders.filter((order) => OPEN_ORDER_STATUSES.has(order.status)).length, 0),
      pendingIntakeCount: buildingRenovations.reduce((sum, row) => sum + row.intakes.filter((intake) => OPEN_INTAKE_STATUSES.has(intake.status)).length, 0),
      tenantMessageStats,
      capacity,
      backlog: buildingRenovations.slice(0, 3),
      nextDueAt: toIso(nextDueAt),
    };
  }).filter((property) => property.renovationCount > 0 || property.capacity.candidateCount > 0 || property.unitCount > 0);

  const summary = {
    propertyCount: properties.length,
    renovationCount: sortedBacklog.length,
    blockedCount: sortedBacklog.filter((row) => row.phase === 'blocked').length,
    readyCount: sortedBacklog.filter((row) => row.phase === 'ready').length,
    overdueTaskCount: sortedBacklog.reduce((sum, row) => sum + row.overdueTaskCount, 0),
    dueSoonTaskCount: sortedBacklog.reduce((sum, row) => sum + row.dueSoonTaskCount, 0),
    openOrderCount: sortedBacklog.reduce((sum, row) => sum + row.orders.filter((order) => OPEN_ORDER_STATUSES.has(order.status)).length, 0),
    pendingIntakeCount: sortedBacklog.reduce((sum, row) => sum + row.intakes.filter((intake) => OPEN_INTAKE_STATUSES.has(intake.status)).length, 0),
    tenantMessageSentCount: sortedBacklog.filter((row) => row.tenantMessageStatus.status === 'sent').length,
    tenantMessageFailedCount: sortedBacklog.filter((row) => row.tenantMessageStatus.status === 'failed').length,
    tenantMessagePendingCount: sortedBacklog.filter((row) => ['not_sent', 'unavailable'].includes(row.tenantMessageStatus.status)).length,
    dispatchableEmployeeCount: properties.reduce((sum, property) => sum + property.capacity.dispatchableCount, 0),
  };

  const reviewQueue = buildReviewQueue({
    backlog: sortedBacklog,
    properties,
    asOf: effectiveNow,
  });

  return {
    summary,
    properties,
    backlog: sortedBacklog.slice(0, safeLimit),
    tenantMessages: sortedBacklog.map((row) => ({
      renovationId: row.id,
      unitId: row.unitId,
      buildingId: row.buildingId,
      buildingName: row.buildingName,
      unitLabel: row.unitLabel,
      tenantPhone: row.tenantPhone,
      ...row.tenantMessageStatus,
    })),
    reviewQueue,
    asOf: effectiveNow.toISOString(),
  };
};

module.exports = {
  getMaintenanceCommandCenter,
  buildBacklogRow,
  buildCapacityForBuilding,
  normalizePhone,
  formatMaintenanceDay,
};
