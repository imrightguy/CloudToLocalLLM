const {
  eq, and, desc, sql, lte, gte, ne, inArray,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  leasesTable, unitsTable, buildingsTable, renewalOffersTable, smsQueueTable,
} = require('../database/schema');
const {
  renewalOfferSchema, updateRenewalOfferSchema, renewalOfferStatusSchema,
  VALID_RENEWAL_TRANSITIONS,
} = require('../models/renewal');
const { child } = require('../utils/logger');

const log = child({ controller: 'renewal' });

const toPublicRenewalOffer = (offer) => ({
  ...offer,
  newRent: offer.newRentCents / 100,
  newDeposit: offer.newDepositCents / 100,
});

const findRenewalOr404 = async (id) => {
  const [offer] = await db
    .select()
    .from(renewalOffersTable)
    .where(eq(renewalOffersTable.id, id))
    .limit(1);
  return offer || null;
};

const getLeasesExpiringWithinDays = async (days) => {
  const now = new Date();
  const windowStart = new Date(now.getTime() + (days - 2) * 24 * 60 * 60 * 1000);
  const windowEnd = new Date(now.getTime() + (days + 2) * 24 * 60 * 60 * 1000);

  return db
    .select()
    .from(leasesTable)
    .where(and(
      eq(leasesTable.isActive, true),
      eq(leasesTable.status, 'active'),
      gte(leasesTable.endDate, windowStart),
      lte(leasesTable.endDate, windowEnd),
    ));
};

exports.getLeasesNeedingRenewal = async (req, res) => {
  try {
    const { window = 90 } = req.query;
    const days = Math.min(180, Math.max(1, parseInt(window)));

    const now = new Date();
    const windowStart = new Date(now.getTime() + (days - 2) * 24 * 60 * 60 * 1000);
    const windowEnd = new Date(now.getTime() + (days + 2) * 24 * 60 * 60 * 1000);

    // Une seule requête : baux + unité + immeuble joints (plus de N+1).
    const rows = await db
      .select()
      .from(leasesTable)
      .leftJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
      .leftJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
      .where(and(
        eq(leasesTable.isActive, true),
        eq(leasesTable.status, 'active'),
        gte(leasesTable.endDate, windowStart),
        lte(leasesTable.endDate, windowEnd),
      ));

    const leaseIds = rows.map((row) => (row.leases || row).id);

    // Une seule requête pour toutes les offres actives non refusées des baux concernés.
    const offers = leaseIds.length > 0
      ? await db
        .select()
        .from(renewalOffersTable)
        .where(and(
          inArray(renewalOffersTable.leaseId, leaseIds),
          eq(renewalOffersTable.isActive, true),
          ne(renewalOffersTable.status, 'declined'),
        ))
        .orderBy(desc(renewalOffersTable.createdAt))
      : [];

    // Regroupement en mémoire : conserver l'offre la plus récente par bail.
    const latestOfferByLease = new Map();
    for (const offer of offers) {
      if (!latestOfferByLease.has(offer.leaseId)) {
        latestOfferByLease.set(offer.leaseId, offer);
      }
    }

    const enriched = rows.map((row) => {
      const lease = row.leases || row;
      const unit = row.units || null;
      const building = row.buildings || null;

      const daysUntilExpiry = Math.ceil(
        (new Date(lease.endDate) - new Date()) / (1000 * 60 * 60 * 24),
      );

      const existingOffer = latestOfferByLease.get(lease.id);

      return {
        ...lease,
        rent: lease.rentCents / 100,
        deposit: lease.depositCents / 100,
        daysUntilExpiry,
        unit: unit || null,
        building: building || null,
        renewalOffer: existingOffer ? toPublicRenewalOffer(existingOffer) : null,
      };
    });

    enriched.sort((a, b) => a.daysUntilExpiry - b.daysUntilExpiry);

    res.json({
      success: true,
      data: enriched,
    });
  } catch (error) {
    log.error('Error fetching leases needing renewal', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_FETCH_FAILED' },
    });
  }
};

exports.createRenewalOffer = async (req, res) => {
  try {
    const { error, value } = renewalOfferSchema.validate(req.body);
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

    if (lease.status !== 'active' && lease.status !== 'expired') {
      return res.status(400).json({
        success: false,
        error: { message: 'Seuls les baux actifs ou expirés peuvent recevoir une offre de renouvellement', code: 'INVALID_LEASE_STATUS' },
      });
    }

    const [offer] = await db
      .insert(renewalOffersTable)
      .values({
        leaseId: value.leaseId,
        newStartDate: new Date(value.newStartDate),
        newEndDate: new Date(value.newEndDate),
        newRentCents: Math.round(value.newRent * 100),
        newDepositCents: Math.round((value.newDeposit || 0) * 100),
        terms: value.terms || {},
        notes: value.notes || null,
        status: 'pending',
      })
      .returning();

    res.status(201).json({
      success: true,
      data: toPublicRenewalOffer(offer),
      message: 'Offre de renouvellement créée avec succès',
    });
  } catch (error) {
    log.error('Error creating renewal offer', { error: error.message });

    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Contrainte de clé étrangère violée', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }

    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_CREATION_FAILED' },
    });
  }
};

exports.getRenewalOffers = async (req, res) => {
  try {
    const { leaseId, status, page = 1, limit = 20 } = req.query;
    const validPage = Math.max(1, parseInt(page));
    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (validPage - 1) * validLimit;

    const conditions = [eq(renewalOffersTable.isActive, true)];
    if (leaseId) {conditions.push(eq(renewalOffersTable.leaseId, leaseId));}
    if (status) {conditions.push(eq(renewalOffersTable.status, status));}

    const whereClause = and(...conditions);

    const [{ count: total }] = await db
      .select({ count: sql`count(*)::int` })
      .from(renewalOffersTable)
      .where(whereClause);

    const offers = await db
      .select()
      .from(renewalOffersTable)
      .where(whereClause)
      .orderBy(desc(renewalOffersTable.createdAt))
      .limit(validLimit)
      .offset(offset);

    const totalPages = Math.ceil(total / validLimit);

    res.json({
      success: true,
      data: offers.map(toPublicRenewalOffer),
      metadata: { total, page: validPage, limit: validLimit, totalPages, hasMore: validPage < totalPages },
    });
  } catch (error) {
    log.error('Error fetching renewal offers', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_FETCH_FAILED' },
    });
  }
};

exports.getRenewalOfferById = async (req, res) => {
  try {
    const { id } = req.params;
    const offer = await findRenewalOr404(id);

    if (!offer) {
      return res.status(404).json({
        success: false,
        error: { message: 'Offre de renouvellement introuvable', code: 'RENEWAL_NOT_FOUND' },
      });
    }

    const [lease] = await db
      .select()
      .from(leasesTable)
      .where(eq(leasesTable.id, offer.leaseId))
      .limit(1);

    res.json({
      success: true,
      data: {
        ...toPublicRenewalOffer(offer),
        lease: lease ? {
          ...lease,
          rent: lease.rentCents / 100,
          deposit: lease.depositCents / 100,
        } : null,
      },
    });
  } catch (error) {
    log.error('Error fetching renewal offer', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_FETCH_FAILED' },
    });
  }
};

exports.updateRenewalOffer = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = updateRenewalOfferSchema.validate(req.body);

    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await findRenewalOr404(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Offre de renouvellement introuvable', code: 'RENEWAL_NOT_FOUND' },
      });
    }

    if (existing.status === 'accepted' || existing.status === 'declined') {
      return res.status(400).json({
        success: false,
        error: { message: 'Impossible de modifier une offre acceptée ou refusée', code: 'RENEWAL_FINALIZED' },
      });
    }

    const updateData = { updatedAt: new Date() };
    if (value.newRent !== undefined) {updateData.newRentCents = Math.round(value.newRent * 100);}
    if (value.newDeposit !== undefined) {updateData.newDepositCents = Math.round(value.newDeposit * 100);}
    if (value.newStartDate !== undefined) {updateData.newStartDate = new Date(value.newStartDate);}
    if (value.newEndDate !== undefined) {updateData.newEndDate = new Date(value.newEndDate);}
    if (value.terms !== undefined) {updateData.terms = value.terms;}
    if (value.notes !== undefined) {updateData.notes = value.notes || null;}

    const [updated] = await db
      .update(renewalOffersTable)
      .set(updateData)
      .where(eq(renewalOffersTable.id, id))
      .returning();

    res.json({
      success: true,
      data: toPublicRenewalOffer(updated),
      message: 'Offre de renouvellement mise à jour avec succès',
    });
  } catch (error) {
    log.error('Error updating renewal offer', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_UPDATE_FAILED' },
    });
  }
};

exports.updateRenewalOfferStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = renewalOfferStatusSchema.validate(req.body);

    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await findRenewalOr404(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Offre de renouvellement introuvable', code: 'RENEWAL_NOT_FOUND' },
      });
    }

    const allowed = VALID_RENEWAL_TRANSITIONS[existing.status] || [];
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

    if (value.status === 'accepted') {
      updateData.respondedAt = new Date();
      updateData.tenantResponse = value.tenantResponse || null;

      const [lease] = await db
        .select()
        .from(leasesTable)
        .where(eq(leasesTable.id, existing.leaseId))
        .limit(1);

      if (lease) {
        await db
          .update(leasesTable)
          .set({
            status: 'renewed',
            startDate: existing.newStartDate,
            endDate: existing.newEndDate,
            rentCents: existing.newRentCents,
            depositCents: existing.newDepositCents,
            terms: existing.terms,
            updatedAt: new Date(),
          })
          .where(eq(leasesTable.id, existing.leaseId));
      }
    }

    if (value.status === 'declined') {
      updateData.respondedAt = new Date();
      updateData.tenantResponse = value.tenantResponse || null;
    }

    if (value.status === 'sent') {
      updateData.sentAt = new Date();
    }

    const [updated] = await db
      .update(renewalOffersTable)
      .set(updateData)
      .where(eq(renewalOffersTable.id, id))
      .returning();

    res.json({
      success: true,
      data: toPublicRenewalOffer(updated),
      message: 'Statut de l\'offre de renouvellement mis à jour',
    });
  } catch (error) {
    log.error('Error updating renewal offer status', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_STATUS_UPDATE_FAILED' },
    });
  }
};

exports.sendRenewalNotification = async (req, res) => {
  try {
    const { id } = req.params;
    const { channel = 'both' } = req.body;

    const offer = await findRenewalOr404(id);
    if (!offer) {
      return res.status(404).json({
        success: false,
        error: { message: 'Offre de renouvellement introuvable', code: 'RENEWAL_NOT_FOUND' },
      });
    }

    const [lease] = await db
      .select()
      .from(leasesTable)
      .where(eq(leasesTable.id, offer.leaseId))
      .limit(1);

    if (!lease) {
      return res.status(404).json({
        success: false,
        error: { message: 'Bail introuvable', code: 'LEASE_NOT_FOUND' },
      });
    }

    const notifications = [];

    if ((channel === 'sms' || channel === 'both') && lease.tenantPhone) {
      const endDate = new Date(lease.endDate).toLocaleDateString('fr-CA', {
        year: 'numeric', month: 'long', day: 'numeric',
      });
      const message = `📋 Offre de renouvellement: Votre bail expire le ${endDate}. Nouveau loyer proposé: ${offer.newRentCents / 100}$ par mois. Contactez-nous pour accepter ou discuter.`;

      await db.insert(smsQueueTable).values({
        reminderType: 'lease_renewal',
        leaseId: lease.id,
        phoneNumber: lease.tenantPhone,
        messageBody: message,
        scheduledAt: new Date(),
        status: 'pending',
        maxRetries: 3,
      });

      notifications.push({ channel: 'sms', phone: lease.tenantPhone });
    }

    if ((channel === 'email' || channel === 'both') && lease.tenantEmail) {
      const { notifyAdminsForEvent } = require('../services/notification.service');
      await notifyAdminsForEvent(
        'lease_renewal',
        'Offre de renouvellement envoyée',
        `Offre de renouvellement envoyée au locataire ${lease.tenantFirstName} ${lease.tenantLastName} pour le bail se terminant le ${lease.endDate}`,
        { leaseId: lease.id, offerId: offer.id },
      );
      notifications.push({ channel: 'email', email: lease.tenantEmail });
    }

    await db
      .update(renewalOffersTable)
      .set({ status: 'sent', sentAt: new Date(), sentVia: channel, updatedAt: new Date() })
      .where(eq(renewalOffersTable.id, id));

    res.json({
      success: true,
      data: { notifications },
      message: 'Notification de renouvellement envoyée',
    });
  } catch (error) {
    log.error('Error sending renewal notification', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_NOTIFICATION_FAILED' },
    });
  }
};

exports.getRenewalOffersByLease = async (req, res) => {
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

    const offers = await db
      .select()
      .from(renewalOffersTable)
      .where(and(
        eq(renewalOffersTable.leaseId, leaseId),
        eq(renewalOffersTable.isActive, true),
      ))
      .orderBy(desc(renewalOffersTable.createdAt));

    res.json({
      success: true,
      data: offers.map(toPublicRenewalOffer),
    });
  } catch (error) {
    log.error('Error fetching lease renewal offers', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_FETCH_FAILED' },
    });
  }
};

exports.generateBulkRenewalOffers = async (req, res) => {
  try {
    const { windowDays = 90, defaultRentIncrease = 0.02, newLeaseDurationMonths = 12 } = req.body;

    const leases = await getLeasesExpiringWithinDays(windowDays);

    const results = [];
    for (const lease of leases) {
      const [existing] = await db
        .select()
        .from(renewalOffersTable)
        .where(and(
          eq(renewalOffersTable.leaseId, lease.id),
          eq(renewalOffersTable.isActive, true),
          ne(renewalOffersTable.status, 'declined'),
        ))
        .limit(1);

      if (existing) {
        results.push({ leaseId: lease.id, status: 'skipped', reason: 'existing_offer' });
        continue;
      }

      const increasedRentCents = Math.round(lease.rentCents * (1 + defaultRentIncrease));
      const currentEnd = new Date(lease.endDate);
      const newStart = new Date(currentEnd);
      const newEnd = new Date(currentEnd);
      newEnd.setMonth(newEnd.getMonth() + newLeaseDurationMonths);

      const [offer] = await db
        .insert(renewalOffersTable)
        .values({
          leaseId: lease.id,
          newStartDate: newStart,
          newEndDate: newEnd,
          newRentCents: increasedRentCents,
          newDepositCents: lease.depositCents,
          terms: lease.terms || {},
          status: 'pending',
        })
        .returning();

      results.push({
        leaseId: lease.id,
        offerId: offer.id,
        status: 'created',
        newRent: increasedRentCents / 100,
        newStartDate: newStart,
        newEndDate: newEnd,
      });
    }

    res.json({
      success: true,
      data: results,
      metadata: {
        total: leases.length,
        created: results.filter(r => r.status === 'created').length,
        skipped: results.filter(r => r.status === 'skipped').length,
      },
    });
  } catch (error) {
    log.error('Error generating bulk renewal offers', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'RENEWAL_BULK_FAILED' },
    });
  }
};
