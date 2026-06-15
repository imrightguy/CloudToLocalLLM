// ─── PlexFlow Ingestion Service ───
// Ingère les données manquantes de PlexFlow dans la DB locale.
// Utilise plexflowService.compareWithLocal() pour le gap analysis.

const plexflowService = require('./plexflow.service');
const buildingService = require('./building.service');
const leaseService = require('./lease.service');
const logger = require('../utils/logger');
const { db } = require('../database/connection');
const { unitsTable } = require('../database/schema');
const { eq, and } = require('drizzle-orm');
const { invalidate } = require('../utils/cache');

/**
 * Ingère les données manquantes de PlexFlow dans la DB locale.
 * @param {string} buildingId
 * @returns {Promise<object>} Rapport d'ingestion
 */
async function ingestMissingData(buildingId) {
  const gap = await plexflowService.compareWithLocal(buildingId);
  if (!gap.configured || gap.error) {
    return { success: false, error: gap.error || 'PlexFlow non configuré' };
  }

  const results = { createdUnits: 0, createdLeases: 0, updatedTenants: 0, errors: [] };

  // Créer les unités manquantes
  for (const unit of gap.missingUnits) {
    try {
      await buildingService.createUnit(buildingId, {
        label: unit.label || 'Unité sans nom',
        floor: unit.floor,
        rooms: unit.rooms,
        rent: unit.rent,
        bedrooms: unit.bedrooms,
        bathrooms: unit.bathrooms,
      });
      results.createdUnits++;
    } catch (error) {
      results.errors.push({ type: 'unit', label: unit.label, error: error.message });
    }
  }

  // Créer les baux manquants
  for (const lease of gap.missingLeases) {
    try {
      await leaseService.createLease({
        buildingId,
        unitLabel: lease.unitLabel,
        tenantName: lease.tenantName,
        rent: lease.rent,
        startDate: lease.startDate,
        endDate: lease.endDate,
      });
      results.createdLeases++;
    } catch (error) {
      results.errors.push({ type: 'lease', unitLabel: lease.unitLabel, error: error.message });
    }
  }

  // Mettre à jour les locataires manquants
  for (const tenant of gap.missingTenants) {
    try {
      const existingUnits = await db
        .select()
        .from(unitsTable)
        .where(and(eq(unitsTable.buildingId, buildingId), eq(unitsTable.isActive, true)))
        .limit(200);

      const match = existingUnits.find(u =>
        u.label && plexflowService.normLabel(u.label) === plexflowService.normLabel(tenant.unitLabel || '')
      );
      if (match) {
        await db.update(unitsTable).set({
          tenantName: tenant.name,
          tenantPhone: tenant.phone || null,
          tenantEmail: tenant.email || null,
          updatedAt: new Date(),
        }).where(eq(unitsTable.id, match.id));
        results.updatedTenants++;
      }
    } catch (error) {
      results.errors.push({ type: 'tenant', name: tenant.name, error: error.message });
    }
  }

  invalidate('plexflow:*');

  return {
    success: true,
    ...results,
    totalProcessed: results.createdUnits + results.createdLeases + results.updatedTenants,
  };
}

module.exports = { ingestMissingData };
