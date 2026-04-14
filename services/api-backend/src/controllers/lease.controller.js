const {
  eq, and, desc, asc, sql,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  leasesTable, unitsTable, buildingsTable, leadsTable,
} = require('../database/schema');
const {
  leaseSchema, updateLeaseSchema, leaseStatusSchema,
  VALID_TRANSITIONS,
} = require('../models/lease');
const { child } = require('../utils/logger');

const log = child({ controller: 'lease' });

const toPublicLease = (lease) => ({
  ...lease,
  rent: lease.rentCents / 100,
  deposit: lease.depositCents / 100,
});

const computeAutoStatus = (startDate, endDate) => {
  const now = new Date();
  if (now < startDate) return 'draft';
  if (now > endDate) return 'expired';
  return 'active';
};

const findLeaseOr404 = async (id) => {
  const [lease] = await db
    .select()
    .from(leasesTable)
    .where(eq(leasesTable.id, id))
    .limit(1);

  if (!lease) return null;
  return lease;
};

exports.createLease = async (req, res) => {
  try {
    const { error, value } = leaseSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const [unit] = await db
      .select()
      .from(unitsTable)
      .where(eq(unitsTable.id, value.unitId))
      .limit(1);

    if (!unit) {
      return res.status(404).json({
        success: false,
        error: { message: "L'unité introuvable", code: 'UNIT_NOT_FOUND' },
      });
    }

    if (value.leadId) {
      const [lead] = await db
        .select({ id: leadsTable.id })
        .from(leadsTable)
        .where(eq(leadsTable.id, value.leadId))
        .limit(1);

      if (!lead) {
        return res.status(404).json({
          success: false,
          error: { message: 'Le prospect est introuvable', code: 'LEAD_NOT_FOUND' },
        });
      }
    }

    const startDate = new Date(value.startDate);
    const endDate = new Date(value.endDate);
    const autoStatus = computeAutoStatus(startDate, endDate);

    const [lease] = await db
      .insert(leasesTable)
      .values({
        unitId: value.unitId,
        leadId: value.leadId || null,
        tenantFirstName: value.tenantFirstName,
        tenantLastName: value.tenantLastName,
        tenantEmail: value.tenantEmail || null,
        tenantPhone: value.tenantPhone || null,
        rentCents: value.rent * 100,
        depositCents: (value.deposit || 0) * 100,
        startDate,
        endDate,
        status: autoStatus,
        terms: value.terms || {},
        createdBy: req.user.id,
      })
      .returning();

    res.status(201).json({
      success: true,
      data: toPublicLease(lease),
      message: 'Bail créé avec succès',
    });
  } catch (error) {
    log.error('Error creating lease', { error: error.message });

    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Contrainte de clé étrangère violée', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }

    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_CREATION_FAILED' },
    });
  }
};

exports.getLeases = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      status,
      buildingId,
      unitId,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const validPage = Math.max(1, parseInt(page));
    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (validPage - 1) * validLimit;

    const conditions = [];
    if (status) conditions.push(eq(leasesTable.status, status));
    if (unitId) conditions.push(eq(leasesTable.unitId, unitId));

    if (buildingId) {
      conditions.push(eq(buildingsTable.id, buildingId));
    }

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    const [{ count: total }] = await db
      .select({ count: sql`count(*)::int` })
      .from(leasesTable)
      .leftJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
      .leftJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
      .where(whereClause);

    const allowedSortFields = {
      createdAt: leasesTable.createdAt,
      updatedAt: leasesTable.updatedAt,
      startDate: leasesTable.startDate,
      endDate: leasesTable.endDate,
      rentCents: leasesTable.rentCents,
      status: leasesTable.status,
    };
    const sortColumn = allowedSortFields[sortBy] || leasesTable.createdAt;
    const orderFn = sortOrder === 'asc' ? asc : desc;

    const leases = await db
      .select()
      .from(leasesTable)
      .where(and(...conditions.filter(c => c)))
      .orderBy(orderFn(sortColumn))
      .limit(validLimit)
      .offset(offset);

    const totalPages = Math.ceil(total / validLimit);

    res.json({
      success: true,
      data: leases.map(toPublicLease),
      metadata: {
        total,
        page: validPage,
        limit: validLimit,
        totalPages,
        hasMore: validPage < totalPages,
      },
    });
  } catch (error) {
    log.error('Error fetching leases', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_FETCH_FAILED' },
    });
  }
};

exports.getLeaseById = async (req, res) => {
  try {
    const { id } = req.params;
    const lease = await findLeaseOr404(id);

    if (!lease) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    const unit = await db
      .select()
      .from(unitsTable)
      .where(eq(unitsTable.id, lease.unitId))
      .limit(1);

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
        ...toPublicLease(lease),
        unit: unit[0] ? {
          ...unit[0],
          rent: unit[0].rentCents / 100,
        } : null,
        building: building[0] || null,
      },
    });
  } catch (error) {
    log.error('Error fetching lease', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_FETCH_FAILED' },
    });
  }
};

exports.updateLease = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = updateLeaseSchema.validate(req.body);

    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await findLeaseOr404(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    if (existing.signedAt) {
      return res.status(400).json({
        success: false,
        error: { message: 'Impossible de modifier un bail signé', code: 'LEASE_ALREADY_SIGNED' },
      });
    }

    const updateData = { updatedAt: new Date() };
    if (value.tenantFirstName !== undefined) updateData.tenantFirstName = value.tenantFirstName;
    if (value.tenantLastName !== undefined) updateData.tenantLastName = value.tenantLastName;
    if (value.tenantEmail !== undefined) updateData.tenantEmail = value.tenantEmail || null;
    if (value.tenantPhone !== undefined) updateData.tenantPhone = value.tenantPhone || null;
    if (value.rent !== undefined) updateData.rentCents = value.rent * 100;
    if (value.deposit !== undefined) updateData.depositCents = value.deposit * 100;
    if (value.startDate !== undefined) updateData.startDate = new Date(value.startDate);
    if (value.endDate !== undefined) updateData.endDate = new Date(value.endDate);
    if (value.terms !== undefined) updateData.terms = value.terms;

    if (updateData.startDate || updateData.endDate) {
      const s = updateData.startDate || existing.startDate;
      const e = updateData.endDate || existing.endDate;
      if (e <= s) {
        return res.status(400).json({
          success: false,
          error: { message: 'La date de fin doit être après la date de début', code: 'VALIDATION_ERROR' },
        });
      }
    }

    const [updated] = await db
      .update(leasesTable)
      .set(updateData)
      .where(eq(leasesTable.id, id))
      .returning();

    res.json({
      success: true,
      data: toPublicLease(updated),
      message: 'Bail mis à jour avec succès',
    });
  } catch (error) {
    log.error('Error updating lease', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_UPDATE_FAILED' },
    });
  }
};

exports.updateLeaseStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = leaseStatusSchema.validate(req.body);

    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await findLeaseOr404(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    const allowed = VALID_TRANSITIONS[existing.status] || [];
    if (!allowed.includes(value.status)) {
      return res.status(400).json({
        success: false,
        error: {
          message: `Transition invalide: ${existing.status} → ${value.status}`,
          code: 'INVALID_STATUS_TRANSITION',
        },
      });
    }

    const [updated] = await db
      .update(leasesTable)
      .set({ status: value.status, updatedAt: new Date() })
      .where(eq(leasesTable.id, id))
      .returning();

    res.json({
      success: true,
      data: toPublicLease(updated),
      message: 'Statut du bail mis à jour',
    });
  } catch (error) {
    log.error('Error updating lease status', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_STATUS_UPDATE_FAILED' },
    });
  }
};

exports.signLease = async (req, res) => {
  try {
    const { id } = req.params;
    const existing = await findLeaseOr404(id);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    if (existing.signedAt) {
      return res.status(400).json({
        success: false,
        error: { message: 'Ce bail est déjà signé', code: 'LEASE_ALREADY_SIGNED' },
      });
    }

    const now = new Date();
    const autoStatus = computeAutoStatus(existing.startDate, existing.endDate);

    const [updated] = await db
      .update(leasesTable)
      .set({
        signedAt: now,
        status: autoStatus,
        updatedAt: now,
      })
      .where(eq(leasesTable.id, id))
      .returning();

    res.json({
      success: true,
      data: toPublicLease(updated),
      message: 'Bail signé avec succès',
    });
  } catch (error) {
    log.error('Error signing lease', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_SIGN_FAILED' },
    });
  }
};

exports.deleteLease = async (req, res) => {
  try {
    const { id } = req.params;
    const existing = await findLeaseOr404(id);

    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    if (existing.status === 'active') {
      return res.status(400).json({
        success: false,
        error: { message: 'Impossible de supprimer un bail actif', code: 'LEASE_ACTIVE' },
      });
    }

    await db
      .update(leasesTable)
      .set({ isActive: false, updatedAt: new Date() })
      .where(eq(leasesTable.id, id));

    res.json({ success: true, data: null, message: 'Bail supprimé avec succès' });
  } catch (error) {
    log.error('Error deleting lease', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_DELETE_FAILED' },
    });
  }
};

exports.getLeasesByBuilding = async (req, res) => {
  try {
    const { id: buildingId } = req.params;

    const [building] = await db
      .select({ id: buildingsTable.id })
      .from(buildingsTable)
      .where(eq(buildingsTable.id, buildingId))
      .limit(1);

    if (!building) {
      return res.status(404).json({
        success: false,
        error: { message: "L'immeuble est introuvable", code: 'BUILDING_NOT_FOUND' },
      });
    }

    const leases = await db
      .select()
      .from(leasesTable)
      .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
      .where(eq(unitsTable.buildingId, buildingId));

    res.json({
      success: true,
      data: leases.map((row) => toPublicLease(row.leases)),
    });
  } catch (error) {
    log.error('Error fetching building leases', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_FETCH_FAILED' },
    });
  }
};

exports.getLeasesByUnit = async (req, res) => {
  try {
    const { id: unitId } = req.params;

    const [unit] = await db
      .select({ id: unitsTable.id })
      .from(unitsTable)
      .where(eq(unitsTable.id, unitId))
      .limit(1);

    if (!unit) {
      return res.status(404).json({
        success: false,
        error: { message: "L'unité est introuvable", code: 'UNIT_NOT_FOUND' },
      });
    }

    const leases = await db
      .select()
      .from(leasesTable)
      .where(eq(leasesTable.unitId, unitId))
      .orderBy(desc(leasesTable.createdAt));

    res.json({
      success: true,
      data: leases.map(toPublicLease),
    });
  } catch (error) {
    log.error('Error fetching unit leases', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'LEASE_FETCH_FAILED' },
    });
  }
};
