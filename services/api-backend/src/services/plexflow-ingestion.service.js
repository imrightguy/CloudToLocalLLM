// ─── PlexFlow Ingestion Service ───
// Ingère les données manquantes de PlexFlow dans la DB locale.
// Utilise plexflowService.compareWithLocal() pour le gap analysis.

const plexflowService = require('./plexflow.service');
const logger = require('../utils/logger');
const { db } = require('../database/connection');
const { unitsTable, leasesTable, buildingsTable } = require('../database/schema');
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
      const label = unit.label || 'Unité sans nom';
      const rentCents = unit.rent != null ? Math.round(unit.rent * 100) : 0;
      const insert = {
        buildingId: gap.localBuildingId || buildingId,
        label,
        rentCents,
        status: 'vacant',
      };
      if (unit.floor != null) {insert.floor = unit.floor;}
      if (unit.rooms != null) {insert.rooms = unit.rooms;}
      if (unit.bedrooms != null) {insert.bedrooms = unit.bedrooms;}
      if (unit.bathrooms != null) {insert.bathrooms = unit.bathrooms;}
      if (unit.plexflowId) {
        insert.amenities = { plexflowId: unit.plexflowId };
      }

      await db.insert(unitsTable).values(insert);
      results.createdUnits++;
    } catch (error) {
      results.errors.push({ type: 'unit', label: unit.label, error: error.message });
    }
  }

  // Créer les baux manquants
  for (const lease of gap.missingLeases) {
    try {
      // Trouver l'unité locale correspondante
      const [localUnit] = await db
        .select()
        .from(unitsTable)
        .where(and(
          eq(unitsTable.buildingId, gap.localBuildingId || buildingId),
          eq(unitsTable.isActive, true),
        ))
        .limit(200);

      const match = localUnit?.find(u =>
        u.label && plexflowService.normLabel(u.label) === plexflowService.normLabel(lease.unitLabel || ''),
      );

      if (!match) {
        results.errors.push({ type: 'lease', unitLabel: lease.unitLabel, error: 'Unité locale non trouvée' });
        continue;
      }

      const tenantName = lease.tenantName || 'Locataire inconnu';
      const [firstName, ...lastParts] = tenantName.split(' ');
      const lastName = lastParts.join(' ') || firstName;

      const rentCents = lease.rent != null ? Math.round(lease.rent * 100) : 0;
      const startDate = lease.startDate ? new Date(lease.startDate) : new Date();
      const endDate = lease.endDate ? new Date(lease.endDate) : new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);

      const insert = {
        unitId: match.id,
        buildingId: gap.localBuildingId || buildingId,
        tenantFirstName: firstName,
        tenantLastName: lastName,
        tenantPhone: null,
        rentCents,
        startDate,
        endDate,
        status: 'active',
        terms: lease.plexflowId ? { plexflowId: lease.plexflowId } : {},
      };

      await db.insert(leasesTable).values(insert);
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
        .where(and(
          eq(unitsTable.buildingId, gap.localBuildingId || buildingId),
          eq(unitsTable.isActive, true),
        ))
        .limit(200);

      const match = existingUnits.find(u =>
        u.label && plexflowService.normLabel(u.label) === plexflowService.normLabel(tenant.unitLabel || ''),
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
