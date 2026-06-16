const {
  eq, and, desc, asc, sql, lte,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  paymentsTable, leasesTable, unitsTable, buildingsTable,
} = require('../database/schema');
const {
  paymentSchema, updatePaymentSchema, paymentStatusSchema,
  VALID_STATUS_TRANSITIONS,
} = require('../models/payment');
const { child } = require('../utils/logger');

const log = child({ controller: 'payment' });

const LATE_FEE_DAILY_RATE = 0.001;
const LATE_FEE_GRACE_DAYS = 3;
const LATE_FEE_MAX_PERCENT = 0.10;

const toPublicPayment = (payment, extra = {}) => ({
  ...payment,
  amount: payment.amountCents / 100,
  lateFee: payment.lateFeeCents / 100,
  total: (payment.amountCents + payment.lateFeeCents) / 100,
  amountPaid: payment.paidDate ? (payment.amountCents / 100) : (extra.amountPaid ?? 0),
  tenantName: extra.tenantName ?? 'Locataire inconnu',
  unitLabel: extra.unitLabel ?? '—',
  buildingName: extra.buildingName ?? '—',
  dueDate: payment.dueDate,
});

const findPaymentOr404 = async (id) => {
  const [payment] = await db
    .select()
    .from(paymentsTable)
    .where(eq(paymentsTable.id, id))
    .limit(1);
  return payment || null;
};

const calculateLateFee = (amountCents, dueDate) => {
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const due = new Date(dueDate);
  due.setHours(0, 0, 0, 0);

  const daysLate = Math.floor((now - due) / (1000 * 60 * 60 * 24)) - LATE_FEE_GRACE_DAYS;
  if (daysLate <= 0) {return 0;}

  const dailyFee = Math.round(amountCents * LATE_FEE_DAILY_RATE);
  const totalFee = dailyFee * daysLate;
  const maxFee = Math.round(amountCents * LATE_FEE_MAX_PERCENT);

  return Math.min(totalFee, maxFee);
};

const autoUpdateOverduePayments = async (leaseId) => {
  const overduePayments = await db
    .select()
    .from(paymentsTable)
    .where(
      and(
        eq(paymentsTable.leaseId, leaseId),
        eq(paymentsTable.status, 'pending'),
        lte(paymentsTable.dueDate, new Date()),
      ),
    );

  const pendingUpdates = overduePayments
    .map((payment) => ({ payment, lateFee: calculateLateFee(payment.amountCents, payment.dueDate) }))
    .filter(({ lateFee }) => lateFee > 0);

  if (pendingUpdates.length === 0) {
    return;
  }

  // Atomique : tous les passages en retard réussissent ou aucun.
  await db.transaction(async (tx) => {
    for (const { payment, lateFee } of pendingUpdates) {
      await tx.update(paymentsTable)
        .set({
          status: 'late',
          lateFeeCents: lateFee,
          updatedAt: new Date(),
        })
        .where(eq(paymentsTable.id, payment.id));
    }
  });
};

exports.createPayment = async (req, res) => {
  try {
    const { error, value } = paymentSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const [lease] = await db
      .select()
      .from(leasesTable)
      .where(eq(leasesTable.id, value.leaseId))
      .limit(1);

    if (!lease) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    const dueDate = new Date(value.dueDate);
    const lateFee = calculateLateFee(lease.rentCents, dueDate);
    const status = lateFee > 0 ? 'late' : 'pending';

    const [payment] = await db
      .insert(paymentsTable)
      .values({
        leaseId: value.leaseId,
        amountCents: Math.round(value.amount * 100),
        lateFeeCents: lateFee,
        dueDate,
        status,
        method: value.method || null,
        reference: value.reference || null,
        notes: value.notes || null,
      })
      .returning();

    res.status(201).json({
      success: true,
      data: toPublicPayment(payment),
      message: 'Paiement créé avec succès',
    });
  } catch (error) {
    log.error('Error creating payment', { error: error.message });

    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Contrainte de clé étrangère violée', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }

    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_CREATION_FAILED' },
    });
  }
};

exports.getPayments = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      status,
      leaseId,
      buildingId,
      sortBy = 'dueDate',
      sortOrder = 'asc',
    } = req.query;

    const validPage = Math.max(1, parseInt(page));
    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (validPage - 1) * validLimit;

    const conditions = [];
    if (status) {conditions.push(eq(paymentsTable.status, status));}
    if (leaseId) {conditions.push(eq(paymentsTable.leaseId, leaseId));}

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    let countQuery = db
      .select({ count: sql`count(*)::int` })
      .from(paymentsTable);

    if (buildingId) {
      countQuery = countQuery
        .innerJoin(leasesTable, eq(paymentsTable.leaseId, leasesTable.id))
        .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
        .where(and(eq(unitsTable.buildingId, buildingId), ...conditions));
    } else {
      countQuery = countQuery.where(whereClause);
    }

    const [{ count: total }] = await countQuery;

    const allowedSortFields = {
      createdAt: paymentsTable.createdAt,
      updatedAt: paymentsTable.updatedAt,
      dueDate: paymentsTable.dueDate,
      amountCents: paymentsTable.amountCents,
      status: paymentsTable.status,
      paidDate: paymentsTable.paidDate,
    };
    const sortColumn = allowedSortFields[sortBy] || paymentsTable.dueDate;
    const orderFn = sortOrder === 'desc' ? desc : asc;

    let dataQuery = db
      .select()
      .from(paymentsTable)
      .innerJoin(leasesTable, eq(paymentsTable.leaseId, leasesTable.id))
      .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
      .where(and(...conditions.filter(Boolean)))
      .orderBy(orderFn(sortColumn))
      .limit(validLimit)
      .offset(offset);

    if (buildingId) {
      conditions.push(eq(unitsTable.buildingId, buildingId));
    } else {
      conditions.push(eq(unitsTable.isActive, true));
    }

    dataQuery = db
      .select()
      .from(paymentsTable)
      .innerJoin(leasesTable, eq(paymentsTable.leaseId, leasesTable.id))
      .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
      .where(and(...conditions.filter(Boolean)))
      .orderBy(orderFn(sortColumn))
      .limit(validLimit)
      .offset(offset);

    const rows = await dataQuery;
    const payments = rows.map((row) => {
      const payment = row.payments || row;
      const lease = row.leases || {};
      const unit = row.units || {};
      return toPublicPayment(payment, {
        tenantName: lease.tenantFirstName && lease.tenantLastName
          ? `${lease.tenantFirstName} ${lease.tenantLastName}`
          : null,
        unitLabel: unit.label,
        buildingName: unit.buildingName,
        amountPaid: payment.paidDate ? payment.amountCents / 100 : 0,
      });
    });

    const totalPages = Math.ceil(total / validLimit);

    res.json({
      success: true,
      data: payments,
      metadata: {
        total,
        page: validPage,
        limit: validLimit,
        totalPages,
        hasMore: validPage < totalPages,
      },
    });
  } catch (error) {
    log.error('Error fetching payments', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_FETCH_FAILED' },
    });
  }
};

exports.getPaymentById = async (req, res) => {
  try {
    const { id } = req.params;
    const payment = await findPaymentOr404(id);

    if (!payment) {
      return res.status(404).json({
        success: false,
        error: { message: 'Paiement introuvable', code: 'PAYMENT_NOT_FOUND' },
      });
    }

    const [lease] = await db
      .select()
      .from(leasesTable)
      .where(eq(leasesTable.id, payment.leaseId))
      .limit(1);

    const unit = lease
      ? await db
        .select()
        .from(unitsTable)
        .where(eq(unitsTable.id, lease.unitId))
        .limit(1)
      : [];

    const building = unit.length > 0 && unit[0].buildingId
      ? await db
        .select()
        .from(buildingsTable)
        .where(eq(buildingsTable.id, unit[0].buildingId))
        .limit(1)
      : [];

    res.json({
      success: true,
      data: {
        ...toPublicPayment(payment),
        lease: lease ? {
          ...lease,
          rent: lease.rentCents / 100,
          deposit: lease.depositCents / 100,
        } : null,
        unit: unit[0] || null,
        building: building[0] || null,
      },
    });
  } catch (error) {
    log.error('Error fetching payment', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_FETCH_FAILED' },
    });
  }
};

exports.updatePayment = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = updatePaymentSchema.validate(req.body);

    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await findPaymentOr404(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Paiement introuvable', code: 'PAYMENT_NOT_FOUND' },
      });
    }

    if (existing.status === 'paid') {
      return res.status(400).json({
        success: false,
        error: { message: 'Impossible de modifier un paiement déjà payé', code: 'PAYMENT_ALREADY_PAID' },
      });
    }

    const updateData = { updatedAt: new Date() };
    if (value.amount !== undefined) {updateData.amountCents = Math.round(value.amount * 100);}
    if (value.paidDate !== undefined) {updateData.paidDate = value.paidDate ? new Date(value.paidDate) : null;}
    if (value.method !== undefined) {updateData.method = value.method || null;}
    if (value.reference !== undefined) {updateData.reference = value.reference || null;}
    if (value.notes !== undefined) {updateData.notes = value.notes || null;}
    if (value.lateFeeCents !== undefined) {updateData.lateFeeCents = value.lateFeeCents;}

    if (updateData.paidDate && !updateData.amountCents) {
      updateData.amountCents = existing.amountCents;
    }

    const [updated] = await db
      .update(paymentsTable)
      .set(updateData)
      .where(eq(paymentsTable.id, id))
      .returning();

    res.json({
      success: true,
      data: toPublicPayment(updated),
      message: 'Paiement mis à jour avec succès',
    });
  } catch (error) {
    log.error('Error updating payment', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_UPDATE_FAILED' },
    });
  }
};

exports.updatePaymentStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = paymentStatusSchema.validate(req.body);

    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await findPaymentOr404(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Paiement introuvable', code: 'PAYMENT_NOT_FOUND' },
      });
    }

    const allowed = VALID_STATUS_TRANSITIONS[existing.status] || [];
    if (!allowed.includes(value.status)) {
      return res.status(400).json({
        success: false,
        error: {
          message: `Transition invalide: ${existing.status} → ${value.status}`,
          code: 'INVALID_STATUS_TRANSITION',
        },
      });
    }

    const updateData = { status: value.status, updatedAt: new Date() };

    if (value.status === 'paid') {
      updateData.paidDate = new Date();
      if (!existing.lateFeeCents || existing.lateFeeCents === 0) {
        const lateFee = calculateLateFee(existing.amountCents, existing.dueDate);
        if (lateFee > 0) {
          updateData.lateFeeCents = lateFee;
        }
      }
    }

    const [updated] = await db
      .update(paymentsTable)
      .set(updateData)
      .where(eq(paymentsTable.id, id))
      .returning();

    res.json({
      success: true,
      data: toPublicPayment(updated),
      message: 'Statut du paiement mis à jour',
    });
  } catch (error) {
    log.error('Error updating payment status', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_STATUS_UPDATE_FAILED' },
    });
  }
};

exports.deletePayment = async (req, res) => {
  try {
    const { id } = req.params;
    const existing = await findPaymentOr404(id);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Paiement introuvable', code: 'PAYMENT_NOT_FOUND' },
      });
    }

    if (existing.status === 'paid') {
      return res.status(400).json({
        success: false,
        error: { message: 'Impossible de supprimer un paiement payé', code: 'PAYMENT_ALREADY_PAID' },
      });
    }

    await db
      .update(paymentsTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(paymentsTable.id, id));

    res.json({ success: true, data: null, message: 'Paiement supprimé avec succès' });
  } catch (error) {
    log.error('Error deleting payment', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_DELETE_FAILED' },
    });
  }
};

exports.getPaymentsByLease = async (req, res) => {
  try {
    const { id: leaseId } = req.params;

    const [lease] = await db
      .select({ id: leasesTable.id })
      .from(leasesTable)
      .where(eq(leasesTable.id, leaseId))
      .limit(1);

    if (!lease) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    await autoUpdateOverduePayments(leaseId);

    const payments = await db
      .select()
      .from(paymentsTable)
      .where(eq(paymentsTable.leaseId, leaseId))
      .orderBy(asc(paymentsTable.dueDate));

    res.json({
      success: true,
      data: payments.map(toPublicPayment),
    });
  } catch (error) {
    log.error('Error fetching lease payments', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_FETCH_FAILED' },
    });
  }
};

exports.getLatePayments = async (req, res) => {
  try {
    const { leaseId, buildingId } = req.query;
    const conditions = [eq(paymentsTable.status, 'late')];

    if (leaseId) {
      conditions.push(eq(paymentsTable.leaseId, leaseId));
    }

    let query;
    if (buildingId) {
      query = db
        .select()
        .from(paymentsTable)
        .innerJoin(leasesTable, eq(paymentsTable.leaseId, leasesTable.id))
        .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
        .where(
          and(
            eq(paymentsTable.status, 'late'),
            eq(unitsTable.buildingId, buildingId),
          ),
        );
    } else {
      query = db
        .select()
        .from(paymentsTable)
        .where(and(...conditions));
    }

    const rows = await query;
    const payments = rows.map((row) => toPublicPayment(row.payments || row));

    const totalLateFees = payments.reduce((sum, p) => sum + p.lateFee, 0);

    res.json({
      success: true,
      data: payments,
      metadata: { totalLateFees },
    });
  } catch (error) {
    log.error('Error fetching late payments', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_FETCH_FAILED' },
    });
  }
};

exports.calculateLateFeePreview = async (req, res) => {
  try {
    const { leaseId } = req.params;

    const [lease] = await db
      .select()
      .from(leasesTable)
      .where(eq(leasesTable.id, leaseId))
      .limit(1);

    if (!lease) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    const lateFee = calculateLateFee(lease.rentCents, new Date());

    res.json({
      success: true,
      data: {
        rentAmount: lease.rentCents / 100,
        lateFee: lateFee / 100,
        totalOwed: (lease.rentCents + lateFee) / 100,
        dailyRate: LATE_FEE_DAILY_RATE * 100,
        graceDays: LATE_FEE_GRACE_DAYS,
        maxPercent: LATE_FEE_MAX_PERCENT * 100,
      },
    });
  } catch (error) {
    log.error('Error calculating late fee preview', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'PAYMENT_CALCULATION_FAILED' },
    });
  }
};
