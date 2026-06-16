const { eq, and, desc, asc, sql } = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  renovationsTable,
  renovationTasksTable,
  renovationOrdersTable,
  renovationReceivingEventsTable,
  renovationSurplusItemsTable,
  workerIntakeRecordsTable,
  unitsTable,
  employeesTable,
} = require('../database/schema');
const {
  renovationRecordSchema,
  updateRenovationRecordSchema,
  renovationTaskSchema,
  updateRenovationTaskSchema,
  renovationOrderSchema,
  updateRenovationOrderSchema,
  receivingEventSchema,
  surplusItemSchema,
  updateRenovationSurplusItemSchema,
  workerIntakeRecordSchema,
  updateWorkerIntakeRecordSchema,
  VALID_RENOVATION_STATUS_TRANSITIONS,
  VALID_RENOVATION_READINESS_TRANSITIONS,
  VALID_RENOVATION_TASK_TRANSITIONS,
  VALID_RENOVATION_ORDER_TRANSITIONS,
  VALID_RENOVATION_SURPLUS_TRANSITIONS,
  hasVerificationEvidence,
} = require('../models/renovation');
const { child } = require('../utils/logger');
const { syncReadinessProjectionByRenovationRecordId } = require('../services/renovation-readiness.service');
const { getMaintenanceCommandCenter } = require('../services/maintenance-command-center.service');

const log = child({ controller: 'renovation' });

const toDateOrNull = (value) => (value ? new Date(value) : null);

const parsePagination = (query) => {
  const page = Math.max(1, parseInt(query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(query.limit, 10) || 20));
  return { page, limit, offset: (page - 1) * limit };
};

const mapMaintenanceDashboard = (data) => ({
  summary: {
    activeApartments: Array.isArray(data.backlog) ? data.backlog.length : 0,
    readyApartments: Array.isArray(data.backlog)
      ? data.backlog.filter((item) => item.phase === 'ready').length
      : 0,
    overdueTasks: data.summary?.overdueTaskCount ?? 0,
    dueSoonTasks: data.summary?.dueSoonTaskCount ?? 0,
    properties: data.summary?.propertyCount ?? 0,
  },
  apartments: Array.isArray(data.backlog) ? data.backlog : [],
  byBuilding: Array.isArray(data.properties)
    ? data.properties.map((property) => ({
      buildingName: property.buildingName,
      apartmentCount: property.unitCount ?? 0,
      overdueTaskCount: property.overdueTaskCount ?? 0,
      dueSoonTaskCount: property.dueSoonTaskCount ?? 0,
    }))
    : [],
  asOf: data.asOf ?? null,
});

const success = (res, data, message, metadata) => {
  const payload = { success: true, data, message };
  if (metadata) { payload.metadata = metadata; }
  return res.json(payload);
};

const error = (res, status, code, message) => res.status(status).json({
  success: false,
  error: { code, message },
});

const mapOrderStatus = (quantityOrdered, quantityReceived) => {
  if (quantityReceived <= 0) { return 'ordered'; }
  if (quantityReceived >= quantityOrdered) { return 'received'; }
  return 'partially_received';
};

const isValidTransition = (transitionMap, from, to) => {
  if (!to || from === to) { return true; }
  return (transitionMap[from] || []).includes(to);
};

const loadRenovationRecord = async (id) => {
  const [record] = await db.select().from(renovationsTable).where(eq(renovationsTable.id, id)).limit(1);
  return record || null;
};

const loadRenovationTask = async (id) => {
  const [task] = await db.select().from(renovationTasksTable).where(eq(renovationTasksTable.id, id)).limit(1);
  return task || null;
};

const loadRenovationOrder = async (id) => {
  const [order] = await db.select().from(renovationOrdersTable).where(eq(renovationOrdersTable.id, id)).limit(1);
  return order || null;
};

exports.getDashboard = async (req, res) => {
  try {
    const { buildingId = null, limit = 12 } = req.query;
    const dashboard = mapMaintenanceDashboard(await getMaintenanceCommandCenter({ buildingId, limit }));

    return success(res, dashboard, 'Tableau des tâches du jour récupéré avec succès');
  } catch (err) {
    log.error('Error fetching renovation dashboard', { error: err.message });
    return error(res, 500, 'RENOVATION_DASHBOARD_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

const loadReceivingEvents = async (orderId) => db
  .select()
  .from(renovationReceivingEventsTable)
  .where(eq(renovationReceivingEventsTable.orderId, orderId))
  .orderBy(asc(renovationReceivingEventsTable.receivedAt));

const loadWorkerIntakeRecord = async (id) => {
  const [record] = await db.select().from(workerIntakeRecordsTable).where(eq(workerIntakeRecordsTable.id, id)).limit(1);
  return record || null;
};

const loadLatestOpenOrder = async ({ renovationRecordId, taskId }) => {
  const conditions = [eq(renovationOrdersTable.renovationRecordId, renovationRecordId)];
  if (taskId) {
    conditions.push(eq(renovationOrdersTable.taskId, taskId));
  }

  const orders = await db
    .select()
    .from(renovationOrdersTable)
    .where(and(...conditions))
    .orderBy(desc(renovationOrdersTable.createdAt));

  return orders.find((order) => ['draft', 'ordered', 'partially_received'].includes(order.status)) || null;
};

exports.getRenovationRecords = async (req, res) => {
  try {
    const { page, limit, offset } = parsePagination(req.query);
    const conditions = [];
    if (req.query.status) { conditions.push(eq(renovationsTable.status, req.query.status)); }
    if (req.query.unitId) { conditions.push(eq(renovationsTable.unitId, req.query.unitId)); }
    if (req.query.buildingId) { conditions.push(eq(renovationsTable.buildingId, req.query.buildingId)); }
    const whereClause = conditions.length ? and(...conditions) : undefined;

    const [{ count: total }] = await db.select({ count: sql`count(*)::int` }).from(renovationsTable).where(whereClause);
    const records = await db
      .select()
      .from(renovationsTable)
      .where(whereClause)
      .orderBy(desc(renovationsTable.createdAt))
      .limit(limit)
      .offset(offset);

    return success(res, records, 'Chantiers récupérés avec succès', {
      total, page, limit, totalPages: Math.ceil((total || 0) / limit) || 0, hasMore: page * limit < total,
    });
  } catch (err) {
    log.error('Error fetching renovation records', { error: err.message });
    return error(res, 500, 'RENOVATION_RECORDS_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

exports.createRenovationRecord = async (req, res) => {
  try {
    const { error: validationError, value } = renovationRecordSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const [unit] = await db.select().from(unitsTable).where(eq(unitsTable.id, value.unitId)).limit(1);
    if (!unit) {
      return error(res, 404, 'UNIT_NOT_FOUND', "L'appartement est introuvable");
    }

    const [record] = await db.insert(renovationsTable).values({
      unitId: value.unitId,
      buildingId: unit.buildingId,
      title: value.title,
      status: value.status || 'planned',
      readinessState: value.readinessState || 'not_started',
      startDate: toDateOrNull(value.startDate),
      targetEndDate: toDateOrNull(value.targetEndDate),
      notes: value.notes || null,
    }).returning();

    await syncReadinessProjectionByRenovationRecordId(record.id);
    return res.status(201).json({ success: true, data: record, message: 'Chantier créé avec succès' });
  } catch (err) {
    log.error('Error creating renovation record', { error: err.message });
    return error(res, 500, 'RENOVATION_RECORD_CREATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.getRenovationRecordById = async (req, res) => {
  try {
    const record = await loadRenovationRecord(req.params.id);
    if (!record) {
      return error(res, 404, 'RENOVATION_RECORD_NOT_FOUND', 'Chantier introuvable');
    }

    const [unit] = await db.select().from(unitsTable).where(eq(unitsTable.id, record.unitId)).limit(1);
    const tasks = await db.select().from(renovationTasksTable).where(eq(renovationTasksTable.renovationRecordId, record.id)).orderBy(desc(renovationTasksTable.createdAt));
    const orders = await db.select().from(renovationOrdersTable).where(eq(renovationOrdersTable.renovationRecordId, record.id)).orderBy(desc(renovationOrdersTable.createdAt));
    const surplus = await db.select().from(renovationSurplusItemsTable).where(eq(renovationSurplusItemsTable.renovationRecordId, record.id)).orderBy(desc(renovationSurplusItemsTable.createdAt));
    const ordersWithReceiving = await Promise.all(orders.map(async (order) => ({
      ...order,
      receivingEvents: await loadReceivingEvents(order.id),
    })));

    return success(res, { ...record, unit: unit || null, tasks, orders: ordersWithReceiving, surplus }, 'Chantier récupéré avec succès');
  } catch (err) {
    log.error('Error fetching renovation record', { error: err.message });
    return error(res, 500, 'RENOVATION_RECORD_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

exports.updateRenovationRecord = async (req, res) => {
  try {
    const { error: validationError, value } = updateRenovationRecordSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const existing = await loadRenovationRecord(req.params.id);
    if (!existing) {
      return error(res, 404, 'RENOVATION_RECORD_NOT_FOUND', 'Chantier introuvable');
    }

    const updates = { updatedAt: new Date() };
    if (value.title !== undefined) { updates.title = value.title; }
    if (value.status !== undefined) {
      if (!isValidTransition(VALID_RENOVATION_STATUS_TRANSITIONS, existing.status, value.status)) {
        return error(res, 400, 'INVALID_RENOVATION_STATUS_TRANSITION', `Transition invalide: ${existing.status} → ${value.status}`);
      }
      updates.status = value.status;
    }
    if (value.readinessState !== undefined) {
      if (!isValidTransition(VALID_RENOVATION_READINESS_TRANSITIONS, existing.readinessState, value.readinessState)) {
        return error(res, 400, 'INVALID_RENOVATION_READINESS_TRANSITION', `Transition de readiness invalide: ${existing.readinessState} → ${value.readinessState}`);
      }
      updates.readinessState = value.readinessState;
    }
    if (value.startDate !== undefined) { updates.startDate = toDateOrNull(value.startDate); }
    if (value.targetEndDate !== undefined) { updates.targetEndDate = toDateOrNull(value.targetEndDate); }
    if (value.notes !== undefined) { updates.notes = value.notes; }

    const [updated] = await db.update(renovationsTable).set(updates).where(eq(renovationsTable.id, existing.id)).returning();
    await syncReadinessProjectionByRenovationRecordId(updated.id);
    return success(res, updated, 'Chantier mis à jour avec succès');
  } catch (err) {
    log.error('Error updating renovation record', { error: err.message });
    return error(res, 500, 'RENOVATION_RECORD_UPDATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.deleteRenovationRecord = async (req, res) => {
  try {
    const existing = await loadRenovationRecord(req.params.id);
    if (!existing) {
      return error(res, 404, 'RENOVATION_RECORD_NOT_FOUND', 'Chantier introuvable');
    }

    await db.update(renovationsTable).set({ isActive: false, updatedAt: new Date() }).where(eq(renovationsTable.id, existing.id));
    await syncReadinessProjectionByRenovationRecordId(existing.id);
    return success(res, null, 'Chantier archivé avec succès');
  } catch (err) {
    log.error('Error deleting renovation record', { error: err.message });
    return error(res, 500, 'RENOVATION_RECORD_DELETE_FAILED', 'Erreur interne du serveur');
  }
};

exports.getRenovationTasks = async (req, res) => {
  try {
    const { page, limit, offset } = parsePagination(req.query);
    const conditions = [];
    if (req.query.renovationRecordId || req.params.id) {
      conditions.push(eq(renovationTasksTable.renovationRecordId, req.params.id || req.query.renovationRecordId));
    }
    if (req.query.status) { conditions.push(eq(renovationTasksTable.status, req.query.status)); }
    const whereClause = conditions.length ? and(...conditions) : undefined;

    const [{ count: total }] = await db.select({ count: sql`count(*)::int` }).from(renovationTasksTable).where(whereClause);
    const tasks = await db.select().from(renovationTasksTable).where(whereClause).orderBy(desc(renovationTasksTable.createdAt)).limit(limit).offset(offset);

    return success(res, tasks, 'Tâches récupérées avec succès', { total, page, limit, totalPages: Math.ceil((total || 0) / limit) || 0, hasMore: page * limit < total });
  } catch (err) {
    log.error('Error fetching renovation tasks', { error: err.message });
    return error(res, 500, 'RENOVATION_TASKS_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

exports.createRenovationTask = async (req, res) => {
  try {
    const { error: validationError, value } = renovationTaskSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const record = await loadRenovationRecord(value.renovationRecordId);
    if (!record) {
      return error(res, 404, 'RENOVATION_RECORD_NOT_FOUND', 'Chantier introuvable');
    }

    if (value.assigneeEmployeeId) {
      const [employee] = await db.select().from(employeesTable).where(eq(employeesTable.id, value.assigneeEmployeeId)).limit(1);
      if (!employee) {
        return error(res, 404, 'EMPLOYEE_NOT_FOUND', 'Employé introuvable');
      }
    }

    const verificationEvidence = value.verificationEvidence || [];
    if (value.status === 'done' && !hasVerificationEvidence(verificationEvidence)) {
      return error(res, 422, 'MISSING_VERIFICATION_EVIDENCE', 'Une preuve de vérification est requise avant de marquer la tâche comme terminée');
    }

    const [task] = await db.insert(renovationTasksTable).values({
      renovationRecordId: value.renovationRecordId,
      assigneeEmployeeId: value.assigneeEmployeeId || null,
      title: value.title,
      description: value.description || null,
      status: value.status || 'todo',
      dueDate: toDateOrNull(value.dueDate),
      verificationEvidence,
      notes: value.notes || null,
    }).returning();

    await syncReadinessProjectionByRenovationRecordId(task.renovationRecordId);
    return res.status(201).json({ success: true, data: task, message: 'Tâche créée avec succès' });
  } catch (err) {
    log.error('Error creating renovation task', { error: err.message });
    return error(res, 500, 'RENOVATION_TASK_CREATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.updateRenovationTask = async (req, res) => {
  try {
    const { error: validationError, value } = updateRenovationTaskSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const existing = await loadRenovationTask(req.params.id);
    if (!existing) {
      return error(res, 404, 'RENOVATION_TASK_NOT_FOUND', 'Tâche introuvable');
    }

    if (value.assigneeEmployeeId) {
      const [employee] = await db.select().from(employeesTable).where(eq(employeesTable.id, value.assigneeEmployeeId)).limit(1);
      if (!employee) {
        return error(res, 404, 'EMPLOYEE_NOT_FOUND', 'Employé introuvable');
      }
    }

    if (value.status && value.status !== existing.status) {
      const allowed = VALID_RENOVATION_TASK_TRANSITIONS[existing.status] || [];
      if (!allowed.includes(value.status)) {
        return error(res, 400, 'INVALID_RENOVATION_TASK_STATUS_TRANSITION', `Transition invalide: ${existing.status} → ${value.status}`);
      }
    }

    const existingVerificationEvidence = hasVerificationEvidence(existing.verificationEvidence) ? existing.verificationEvidence : [];
    const requestedVerificationEvidence = value.verificationEvidence !== undefined ? value.verificationEvidence : null;
    const effectiveVerificationEvidence = requestedVerificationEvidence || existingVerificationEvidence;
    if (value.status === 'done' && !hasVerificationEvidence(effectiveVerificationEvidence)) {
      return error(res, 422, 'MISSING_VERIFICATION_EVIDENCE', 'Une preuve de vérification est requise avant de marquer la tâche comme terminée');
    }

    const updates = { updatedAt: new Date() };
    if (value.assigneeEmployeeId !== undefined) { updates.assigneeEmployeeId = value.assigneeEmployeeId; }
    if (value.title !== undefined) { updates.title = value.title; }
    if (value.description !== undefined) { updates.description = value.description; }
    if (value.status !== undefined) {
      updates.status = value.status;
      updates.completedAt = value.status === 'done' ? new Date() : null;
    }
    if (value.verificationEvidence !== undefined) { updates.verificationEvidence = requestedVerificationEvidence; }
    if (value.dueDate !== undefined) { updates.dueDate = toDateOrNull(value.dueDate); }
    if (value.notes !== undefined) { updates.notes = value.notes; }

    const [updated] = await db.update(renovationTasksTable).set(updates).where(eq(renovationTasksTable.id, existing.id)).returning();
    await syncReadinessProjectionByRenovationRecordId(updated.renovationRecordId);
    return success(res, updated, 'Tâche mise à jour avec succès');
  } catch (err) {
    log.error('Error updating renovation task', { error: err.message });
    return error(res, 500, 'RENOVATION_TASK_UPDATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.deleteRenovationTask = async (req, res) => {
  try {
    const existing = await loadRenovationTask(req.params.id);
    if (!existing) {
      return error(res, 404, 'RENOVATION_TASK_NOT_FOUND', 'Tâche introuvable');
    }
    await db.update(renovationTasksTable).set({ isActive: false, updatedAt: new Date() }).where(eq(renovationTasksTable.id, existing.id));
    await syncReadinessProjectionByRenovationRecordId(existing.renovationRecordId);
    return success(res, null, 'Tâche archivée avec succès');
  } catch (err) {
    log.error('Error deleting renovation task', { error: err.message });
    return error(res, 500, 'RENOVATION_TASK_DELETE_FAILED', 'Erreur interne du serveur');
  }
};

exports.getRenovationOrders = async (req, res) => {
  try {
    const { page, limit, offset } = parsePagination(req.query);
    const conditions = [];
    if (req.params.id || req.query.renovationRecordId) {
      conditions.push(eq(renovationOrdersTable.renovationRecordId, req.params.id || req.query.renovationRecordId));
    }
    if (req.query.status) { conditions.push(eq(renovationOrdersTable.status, req.query.status)); }
    const whereClause = conditions.length ? and(...conditions) : undefined;

    const [{ count: total }] = await db.select({ count: sql`count(*)::int` }).from(renovationOrdersTable).where(whereClause);
    const orders = await db.select().from(renovationOrdersTable).where(whereClause).orderBy(desc(renovationOrdersTable.createdAt)).limit(limit).offset(offset);

    return success(res, orders, 'Commandes récupérées avec succès', { total, page, limit, totalPages: Math.ceil((total || 0) / limit) || 0, hasMore: page * limit < total });
  } catch (err) {
    log.error('Error fetching renovation orders', { error: err.message });
    return error(res, 500, 'RENOVATION_ORDERS_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

exports.createRenovationOrder = async (req, res) => {
  try {
    const { error: validationError, value } = renovationOrderSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const record = await loadRenovationRecord(value.renovationRecordId);
    if (!record) {
      return error(res, 404, 'RENOVATION_RECORD_NOT_FOUND', 'Chantier introuvable');
    }

    if (value.taskId) {
      const [task] = await db.select().from(renovationTasksTable).where(eq(renovationTasksTable.id, value.taskId)).limit(1);
      if (!task || task.renovationRecordId !== value.renovationRecordId) {
        return error(res, 404, 'RENOVATION_TASK_NOT_FOUND', 'Tâche introuvable');
      }
    }

    const [order] = await db.insert(renovationOrdersTable).values({
      renovationRecordId: value.renovationRecordId,
      taskId: value.taskId || null,
      vendorName: value.vendorName,
      itemName: value.itemName,
      quantityOrdered: value.quantityOrdered,
      quantityReceived: value.quantityReceived || 0,
      status: value.status || 'draft',
      orderedAt: toDateOrNull(value.orderedAt),
      expectedAt: toDateOrNull(value.expectedAt),
      notes: value.notes || null,
    }).returning();

    return res.status(201).json({ success: true, data: order, message: 'Commande créée avec succès' });
  } catch (err) {
    log.error('Error creating renovation order', { error: err.message });
    return error(res, 500, 'RENOVATION_ORDER_CREATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.updateRenovationOrder = async (req, res) => {
  try {
    const { error: validationError, value } = updateRenovationOrderSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const existing = await loadRenovationOrder(req.params.id);
    if (!existing) {
      return error(res, 404, 'RENOVATION_ORDER_NOT_FOUND', 'Commande introuvable');
    }

    const updates = { updatedAt: new Date() };
    if (value.taskId !== undefined) { updates.taskId = value.taskId; }
    if (value.vendorName !== undefined) { updates.vendorName = value.vendorName; }
    if (value.itemName !== undefined) { updates.itemName = value.itemName; }
    if (value.quantityOrdered !== undefined) { updates.quantityOrdered = value.quantityOrdered; }
    if (value.quantityReceived !== undefined) { updates.quantityReceived = value.quantityReceived; }
    if (value.status !== undefined) {
      if (!isValidTransition(VALID_RENOVATION_ORDER_TRANSITIONS, existing.status, value.status)) {
        return error(res, 400, 'INVALID_RENOVATION_ORDER_STATUS_TRANSITION', `Transition invalide: ${existing.status} → ${value.status}`);
      }
      updates.status = value.status;
    }
    if (value.orderedAt !== undefined) { updates.orderedAt = toDateOrNull(value.orderedAt); }
    if (value.expectedAt !== undefined) { updates.expectedAt = toDateOrNull(value.expectedAt); }
    if (value.notes !== undefined) { updates.notes = value.notes; }

    const [updated] = await db.update(renovationOrdersTable).set(updates).where(eq(renovationOrdersTable.id, existing.id)).returning();
    return success(res, updated, 'Commande mise à jour avec succès');
  } catch (err) {
    log.error('Error updating renovation order', { error: err.message });
    return error(res, 500, 'RENOVATION_ORDER_UPDATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.deleteRenovationOrder = async (req, res) => {
  try {
    const existing = await loadRenovationOrder(req.params.id);
    if (!existing) {
      return error(res, 404, 'RENOVATION_ORDER_NOT_FOUND', 'Commande introuvable');
    }
    await db.update(renovationOrdersTable).set({ isActive: false, updatedAt: new Date() }).where(eq(renovationOrdersTable.id, existing.id));
    return success(res, null, 'Commande archivée avec succès');
  } catch (err) {
    log.error('Error deleting renovation order', { error: err.message });
    return error(res, 500, 'RENOVATION_ORDER_DELETE_FAILED', 'Erreur interne du serveur');
  }
};

exports.createReceivingEvent = async (req, res) => {
  try {
    const { error: validationError, value } = receivingEventSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const order = await loadRenovationOrder(req.params.id);
    if (!order) {
      return error(res, 404, 'RENOVATION_ORDER_NOT_FOUND', 'Commande introuvable');
    }

    const totalQuantityReceived = (order.quantityReceived || 0) + value.quantityReceived;
    if (totalQuantityReceived > order.quantityOrdered) {
      return error(res, 400, 'RENOVATION_RECEIVING_QUANTITY_EXCEEDS_ORDER', 'La quantité reçue dépasse la quantité commandée');
    }

    const nextStatus = mapOrderStatus(order.quantityOrdered, totalQuantityReceived);

    // Atomique : l'événement de réception et la mise à jour de la commande
    // sont écrits ensemble ou pas du tout.
    const { event, updatedOrder } = await db.transaction(async (tx) => {
      const [insertedEvent] = await tx.insert(renovationReceivingEventsTable).values({
        orderId: order.id,
        quantityReceived: value.quantityReceived,
        receivedAt: new Date(),
        notes: value.notes || null,
      }).returning();

      const [updated] = await tx.update(renovationOrdersTable).set({
        quantityReceived: totalQuantityReceived,
        status: nextStatus,
        updatedAt: new Date(),
      }).where(eq(renovationOrdersTable.id, order.id)).returning();

      return { event: insertedEvent, updatedOrder: updated };
    });

    return res.status(201).json({
      success: true,
      data: {
        ...event,
        order: updatedOrder,
      },
      message: 'Réception enregistrée avec succès',
    });
  } catch (err) {
    log.error('Error creating renovation receiving event', { error: err.message });
    return error(res, 500, 'RENOVATION_RECEIVING_EVENT_CREATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.getRenovationReceivingEvents = async (req, res) => {
  try {
    const order = await loadRenovationOrder(req.params.id);
    if (!order) {
      return error(res, 404, 'RENOVATION_ORDER_NOT_FOUND', 'Commande introuvable');
    }

    const events = await loadReceivingEvents(order.id);
    return success(res, events, 'Réceptions récupérées avec succès');
  } catch (err) {
    log.error('Error fetching renovation receiving events', { error: err.message });
    return error(res, 500, 'RENOVATION_RECEIVING_EVENTS_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

exports.getRenovationSurplusItems = async (req, res) => {
  try {
    const { page, limit, offset } = parsePagination(req.query);
    const conditions = [];
    if (req.params.id || req.query.renovationRecordId) {
      conditions.push(eq(renovationSurplusItemsTable.renovationRecordId, req.params.id || req.query.renovationRecordId));
    }
    if (req.query.status) { conditions.push(eq(renovationSurplusItemsTable.status, req.query.status)); }
    const whereClause = conditions.length ? and(...conditions) : undefined;

    const [{ count: total }] = await db.select({ count: sql`count(*)::int` }).from(renovationSurplusItemsTable).where(whereClause);
    const items = await db.select().from(renovationSurplusItemsTable).where(whereClause).orderBy(desc(renovationSurplusItemsTable.createdAt)).limit(limit).offset(offset);

    return success(res, items, 'Surplus récupérés avec succès', { total, page, limit, totalPages: Math.ceil((total || 0) / limit) || 0, hasMore: page * limit < total });
  } catch (err) {
    log.error('Error fetching renovation surplus', { error: err.message });
    return error(res, 500, 'RENOVATION_SURPLUS_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

exports.createRenovationSurplusItem = async (req, res) => {
  try {
    const { error: validationError, value } = surplusItemSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const record = await loadRenovationRecord(value.renovationRecordId);
    if (!record) {
      return error(res, 404, 'RENOVATION_RECORD_NOT_FOUND', 'Chantier introuvable');
    }

    const [item] = await db.insert(renovationSurplusItemsTable).values({
      renovationRecordId: value.renovationRecordId,
      sourceOrderId: value.sourceOrderId || null,
      taskId: value.taskId || null,
      itemName: value.itemName,
      quantityAvailable: value.quantityAvailable,
      status: value.status || 'available',
      location: value.location || null,
      notes: value.notes || null,
    }).returning();

    return res.status(201).json({ success: true, data: item, message: 'Surplus créé avec succès' });
  } catch (err) {
    log.error('Error creating renovation surplus item', { error: err.message });
    return error(res, 500, 'RENOVATION_SURPLUS_CREATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.updateRenovationSurplusItem = async (req, res) => {
  try {
    const { error: validationError, value } = updateRenovationSurplusItemSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const [existing] = await db.select().from(renovationSurplusItemsTable).where(eq(renovationSurplusItemsTable.id, req.params.id)).limit(1);
    if (!existing) {
      return error(res, 404, 'RENOVATION_SURPLUS_NOT_FOUND', 'Surplus introuvable');
    }

    const updates = { updatedAt: new Date() };
    if (value.sourceOrderId !== undefined) { updates.sourceOrderId = value.sourceOrderId; }
    if (value.taskId !== undefined) { updates.taskId = value.taskId; }
    if (value.itemName !== undefined) { updates.itemName = value.itemName; }
    if (value.quantityAvailable !== undefined) { updates.quantityAvailable = value.quantityAvailable; }
    if (value.status !== undefined) {
      if (!isValidTransition(VALID_RENOVATION_SURPLUS_TRANSITIONS, existing.status, value.status)) {
        return error(res, 400, 'INVALID_RENOVATION_SURPLUS_STATUS_TRANSITION', `Transition invalide: ${existing.status} → ${value.status}`);
      }
      updates.status = value.status;
    }
    if (value.location !== undefined) { updates.location = value.location; }
    if (value.notes !== undefined) { updates.notes = value.notes; }

    const [updated] = await db.update(renovationSurplusItemsTable).set(updates).where(eq(renovationSurplusItemsTable.id, existing.id)).returning();
    return success(res, updated, 'Surplus mis à jour avec succès');
  } catch (err) {
    log.error('Error updating renovation surplus item', { error: err.message });
    return error(res, 500, 'RENOVATION_SURPLUS_UPDATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.deleteRenovationSurplusItem = async (req, res) => {
  try {
    const [existing] = await db.select().from(renovationSurplusItemsTable).where(eq(renovationSurplusItemsTable.id, req.params.id)).limit(1);
    if (!existing) {
      return error(res, 404, 'RENOVATION_SURPLUS_NOT_FOUND', 'Surplus introuvable');
    }
    await db.update(renovationSurplusItemsTable).set({ isActive: false, updatedAt: new Date() }).where(eq(renovationSurplusItemsTable.id, existing.id));
    return success(res, null, 'Surplus archivé avec succès');
  } catch (err) {
    log.error('Error deleting renovation surplus item', { error: err.message });
    return error(res, 500, 'RENOVATION_SURPLUS_DELETE_FAILED', 'Erreur interne du serveur');
  }
};


exports.getRenovationWorkerIntakeRecords = async (req, res) => {
  try {
    const { page, limit, offset } = parsePagination(req.query);
    const conditions = [];
    if (req.params.id || req.query.renovationRecordId) {
      conditions.push(eq(workerIntakeRecordsTable.renovationRecordId, req.params.id || req.query.renovationRecordId));
    }
    if (req.query.status) {
      conditions.push(eq(workerIntakeRecordsTable.status, req.query.status));
    }
    if (req.query.messageKind) {
      conditions.push(eq(workerIntakeRecordsTable.messageKind, req.query.messageKind));
    }
    const whereClause = conditions.length ? and(...conditions) : undefined;

    const [{ count: total }] = await db.select({ count: sql`count(*)::int` }).from(workerIntakeRecordsTable).where(whereClause);
    const records = await db
      .select()
      .from(workerIntakeRecordsTable)
      .where(whereClause)
      .orderBy(desc(workerIntakeRecordsTable.createdAt))
      .limit(limit)
      .offset(offset);

    return success(res, records, "Messages d'intake récupérés avec succès", {
      total, page, limit, totalPages: Math.ceil((total || 0) / limit) || 0, hasMore: page * limit < total,
    });
  } catch (err) {
    log.error('Error fetching worker intake records', { error: err.message });
    return error(res, 500, 'WORKER_INTAKE_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

exports.createRenovationWorkerIntakeRecord = async (req, res) => {
  try {
    const { error: validationError, value } = workerIntakeRecordSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const record = await loadRenovationRecord(value.renovationRecordId);
    if (!record) {
      return error(res, 404, 'RENOVATION_RECORD_NOT_FOUND', 'Chantier introuvable');
    }

    let resolvedTaskId = value.taskId || null;
    let resolvedOrderId = value.orderId || null;

    if (resolvedTaskId) {
      const task = await loadRenovationTask(resolvedTaskId);
      if (!task || task.renovationRecordId !== value.renovationRecordId) {
        return error(res, 404, 'RENOVATION_TASK_NOT_FOUND', 'Tâche introuvable');
      }
    }

    if (resolvedOrderId) {
      const order = await loadRenovationOrder(resolvedOrderId);
      if (!order || order.renovationRecordId !== value.renovationRecordId) {
        return error(res, 404, 'RENOVATION_ORDER_NOT_FOUND', 'Commande introuvable');
      }
      if (!resolvedTaskId && order.taskId) {
        resolvedTaskId = order.taskId;
      }
    }

    if (!resolvedOrderId && ['missing_material', 'blocker', 'surplus'].includes(value.messageKind)) {
      const matchedOrder = await loadLatestOpenOrder({ renovationRecordId: value.renovationRecordId, taskId: resolvedTaskId });
      if (matchedOrder) {
        resolvedOrderId = matchedOrder.id;
        if (!resolvedTaskId && matchedOrder.taskId) {
          resolvedTaskId = matchedOrder.taskId;
        }
      }
    }

    const mediaUrls = value.mediaUrls || [];
    const mediaContentTypes = value.mediaContentTypes || [];
    const photoCount = value.photoCount ?? mediaUrls.length;

    const [recordRow] = await db.insert(workerIntakeRecordsTable).values({
      twilioMessageSid: value.twilioMessageSid || null,
      renovationRecordId: value.renovationRecordId,
      taskId: resolvedTaskId,
      orderId: resolvedOrderId,
      sourcePhone: value.sourcePhone,
      workerName: value.workerName || null,
      messageBody: value.messageBody,
      messageKind: value.messageKind || 'update',
      status: value.status || (resolvedTaskId || resolvedOrderId ? 'linked' : 'new'),
      confidence: value.confidence ?? null,
      summary: value.summary || null,
      rawPayload: value.rawPayload || {},
      mediaUrls,
      mediaContentTypes,
      photoCount,
      receivedAt: toDateOrNull(value.receivedAt) || new Date(),
      reviewedAt: toDateOrNull(value.reviewedAt),
      resolvedAt: toDateOrNull(value.resolvedAt),
      notes: value.notes || null,
    }).returning();

    await syncReadinessProjectionByRenovationRecordId(recordRow.renovationRecordId);
    return res.status(201).json({ success: true, data: recordRow, message: "Message d'intake créé avec succès" });
  } catch (err) {
    log.error('Error creating worker intake record', { error: err.message });
    return error(res, 500, 'WORKER_INTAKE_CREATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.updateRenovationWorkerIntakeRecord = async (req, res) => {
  try {
    const { error: validationError, value } = updateWorkerIntakeRecordSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const existing = await loadWorkerIntakeRecord(req.params.id);
    if (!existing) {
      return error(res, 404, 'WORKER_INTAKE_NOT_FOUND', "Message d'intake introuvable");
    }

    if (value.taskId !== undefined) {
      if (value.taskId === null) {
        value.taskId = null;
      } else {
        const task = await loadRenovationTask(value.taskId);
        if (!task || task.renovationRecordId !== existing.renovationRecordId) {
          return error(res, 404, 'RENOVATION_TASK_NOT_FOUND', 'Tâche introuvable');
        }
      }
    }

    if (value.orderId !== undefined) {
      if (value.orderId === null) {
        value.orderId = null;
      } else {
        const order = await loadRenovationOrder(value.orderId);
        if (!order || order.renovationRecordId !== existing.renovationRecordId) {
          return error(res, 404, 'RENOVATION_ORDER_NOT_FOUND', 'Commande introuvable');
        }
      }
    }

    const updates = { updatedAt: new Date() };
    if (value.taskId !== undefined) { updates.taskId = value.taskId; }
    if (value.orderId !== undefined) { updates.orderId = value.orderId; }
    if (value.sourcePhone !== undefined) { updates.sourcePhone = value.sourcePhone; }
    if (value.workerName !== undefined) { updates.workerName = value.workerName; }
    if (value.messageBody !== undefined) { updates.messageBody = value.messageBody; }
    if (value.messageKind !== undefined) { updates.messageKind = value.messageKind; }
    if (value.status !== undefined) { updates.status = value.status; }
    if (value.confidence !== undefined) { updates.confidence = value.confidence; }
    if (value.summary !== undefined) { updates.summary = value.summary; }
    if (value.rawPayload !== undefined) { updates.rawPayload = value.rawPayload; }
    if (value.twilioMessageSid !== undefined) { updates.twilioMessageSid = value.twilioMessageSid || null; }
    if (value.mediaUrls !== undefined) { updates.mediaUrls = value.mediaUrls; }
    if (value.mediaContentTypes !== undefined) { updates.mediaContentTypes = value.mediaContentTypes; }
    if (value.photoCount !== undefined) { updates.photoCount = value.photoCount; }
    if (value.receivedAt !== undefined) { updates.receivedAt = toDateOrNull(value.receivedAt); }
    if (value.reviewedAt !== undefined) { updates.reviewedAt = toDateOrNull(value.reviewedAt); }
    if (value.resolvedAt !== undefined) { updates.resolvedAt = toDateOrNull(value.resolvedAt); }
    if (value.notes !== undefined) { updates.notes = value.notes; }

    const [updated] = await db.update(workerIntakeRecordsTable).set(updates).where(eq(workerIntakeRecordsTable.id, existing.id)).returning();
    await syncReadinessProjectionByRenovationRecordId(updated.renovationRecordId);
    return success(res, updated, "Message d'intake mis à jour avec succès");
  } catch (err) {
    log.error('Error updating worker intake record', { error: err.message });
    return error(res, 500, 'WORKER_INTAKE_UPDATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.deleteRenovationWorkerIntakeRecord = async (req, res) => {
  try {
    const existing = await loadWorkerIntakeRecord(req.params.id);
    if (!existing) {
      return error(res, 404, 'WORKER_INTAKE_NOT_FOUND', "Message d'intake introuvable");
    }

    await db.update(workerIntakeRecordsTable).set({ isActive: false, updatedAt: new Date() }).where(eq(workerIntakeRecordsTable.id, existing.id));
    await syncReadinessProjectionByRenovationRecordId(existing.renovationRecordId);
    return success(res, null, "Message d'intake archivé avec succès");
  } catch (err) {
    log.error('Error deleting worker intake record', { error: err.message });
    return error(res, 500, 'WORKER_INTAKE_DELETE_FAILED', 'Erreur interne du serveur');
  }
};
