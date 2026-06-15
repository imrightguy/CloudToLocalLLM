const { eq, and, sql } = require('drizzle-orm');
const { cache, invalidate } = require('../utils/cache');
const logger = require('../utils/logger');
const { db } = require('../database/connection');
const { buildingsTable, unitsTable, leasesTable } = require('../database/schema');

const CACHE_TTL_SECONDS = 3600;
const REQUEST_TIMEOUT_MS = 8000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isConfigured() {
  return Boolean(process.env.PLEXFLOW_API_URL);
}

function asArray(raw) {
  if (Array.isArray(raw)) {
    return raw;
  }
  if (raw && Array.isArray(raw.data)) {
    return raw.data;
  }
  return [];
}

async function plexflowGet(path) {
  const baseUrl = process.env.PLEXFLOW_API_URL;
  if (!baseUrl) {
    return null;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const headers = { 'Content-Type': 'application/json' };
    if (process.env.PLEXFLOW_API_KEY) {
      headers['X-Plexflow-Key'] = process.env.PLEXFLOW_API_KEY;
    }

    const response = await fetch(`${baseUrl}${path}`, {
      method: 'GET',
      headers,
      signal: controller.signal,
    });

    if (!response.ok) {
      logger.warn('[plexflow.service] non-2xx response', { path, status: response.status });
      return null;
    }

    return await response.json();
  } catch (error) {
    logger.warn('[plexflow.service] request failed', { path, error: error.message });
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

async function cachedGet(cacheKey, path) {
  const cached = cache.get(cacheKey);
  if (cached !== undefined) {
    return cached;
  }
  const raw = await plexflowGet(path);
  if (raw === null) {
    // Échec/timeout de l'API PlexFlow: ne pas cacher pour éviter de figer
    // des données vides pendant tout le TTL. On réessaiera au prochain appel.
    return [];
  }
  const data = asArray(raw);
  cache.set(cacheKey, data, CACHE_TTL_SECONDS);
  return data;
}

async function getBuildings() {
  return cachedGet('plexflow:buildings', '/buildings');
}

async function getUnits(buildingId) {
  const encoded = encodeURIComponent(buildingId);
  return cachedGet(`plexflow:units:${buildingId}`, `/buildings/${encoded}/units`);
}

async function getLeases(unitId) {
  const encoded = encodeURIComponent(unitId);
  return cachedGet(`plexflow:leases:${unitId}`, `/units/${encoded}/leases`);
}

async function getTenants(unitId) {
  const encoded = encodeURIComponent(unitId);
  return cachedGet(`plexflow:tenants:${unitId}`, `/units/${encoded}/tenants`);
}

async function syncAll() {
  invalidate('plexflow:*');
  const buildings = await getBuildings();
  return {
    configured: isConfigured(),
    syncedAt: new Date().toISOString(),
    buildingCount: buildings.length,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Gap analysis — comparaison PlexFlow ↔ DB locale
//
//  Les enregistrements PlexFlow utilisent des noms de champs inconnus/variables.
//  On extrait défensivement chaque valeur via une liste d'alias.
// ─────────────────────────────────────────────────────────────────────────────

// Premier alias non vide d'un objet.
function pick(obj, keys) {
  if (!obj || typeof obj !== 'object') {
    return undefined;
  }
  for (const key of keys) {
    const value = obj[key];
    if (value !== undefined && value !== null && value !== '') {
      return value;
    }
  }
  return undefined;
}

function normLabel(value) {
  return String(value === null || value === undefined ? '' : value).trim().toLowerCase();
}

function leaseKey(unitLabel, tenantName) {
  return `${normLabel(unitLabel)}|${normLabel(tenantName)}`;
}

function numOrNull(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function plexBuildingId(b) { return pick(b, ['id', 'plexflowId', 'buildingId', '_id']); }
function plexUnitId(u) { return pick(u, ['id', 'plexflowId', 'unitId', '_id']); }
function plexUnitLabel(u) { return pick(u, ['label', 'unitNumber', 'number', 'name']); }
function plexLeaseId(l) { return pick(l, ['id', 'plexflowId', 'leaseId', '_id']); }
function plexTenantId(t) { return pick(t, ['id', 'plexflowId', 'tenantId', '_id']); }

// Nom complet à partir d'un champ direct ou de prénom/nom séparés.
function fullName(obj) {
  const direct = pick(obj, ['name', 'fullName', 'tenantName', 'displayName']);
  if (direct) {
    return String(direct).trim();
  }
  const first = pick(obj, ['firstName', 'tenantFirstName', 'first_name', 'given_name']);
  const last = pick(obj, ['lastName', 'tenantLastName', 'last_name', 'family_name']);
  const joined = [first, last].filter(Boolean).join(' ').trim();
  return joined || undefined;
}

// plexflowId stocké dans un champ jsonb local (amenities pour les unités,
// terms pour les baux). Renvoie undefined si jsonb est un tableau / vide.
function jsonField(value, key) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value[key];
  }
  return undefined;
}

/**
 * Bâtiment local lié à un bâtiment PlexFlow.
 * Lien via properties.plexflowId, ou par id si l'identifiant est déjà un UUID.
 */
async function findLocalBuilding(plexflowBuildingId) {
  const id = String(plexflowBuildingId);
  const linked = await db
    .select()
    .from(buildingsTable)
    .where(and(
      sql`${buildingsTable.properties} ->> 'plexflowId' = ${id}`,
      eq(buildingsTable.isActive, true),
    ))
    .limit(1);
  if (linked.length > 0) {
    return linked[0];
  }
  if (UUID_RE.test(id)) {
    const [byId] = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, id))
      .limit(1);
    if (byId) {
      return byId;
    }
  }
  return null;
}

/**
 * Snapshot complet d'un bâtiment PlexFlow: building + units + leases + tenants.
 * Les leases/tenants sont aplatis et annotés avec l'unité PlexFlow d'origine.
 */
async function getFullSnapshot(buildingId) {
  if (!isConfigured()) {
    return { configured: false, error: 'PlexFlow indisponible' };
  }

  const buildings = await getBuildings();
  const building = buildings.find((b) => String(plexBuildingId(b)) === String(buildingId)) || null;

  const units = await getUnits(buildingId);

  const leases = [];
  const tenants = [];

  await Promise.all(units.map(async (unit) => {
    const unitId = plexUnitId(unit);
    if (unitId === undefined) {
      return;
    }
    const unitLabel = plexUnitLabel(unit) || null;
    const [unitLeases, unitTenants] = await Promise.all([
      getLeases(unitId),
      getTenants(unitId),
    ]);
    for (const lease of unitLeases) {
      leases.push({ ...lease, _unitPlexflowId: unitId, _unitLabel: unitLabel });
    }
    for (const tenant of unitTenants) {
      tenants.push({ ...tenant, _unitPlexflowId: unitId, _unitLabel: unitLabel });
    }
  }));

  return {
    configured: true,
    buildingId,
    building,
    buildingName: building ? (pick(building, ['name', 'label']) || null) : null,
    buildingInfo: building ? {
      name: pick(building, ['name', 'label']) || null,
      address: pick(building, ['address', 'street', 'addressLine1']) || null,
      city: pick(building, ['city']) || null,
      province: pick(building, ['province', 'state']) || null,
      postalCode: pick(building, ['postalCode', 'zip', 'postal_code']) || null,
    } : null,
    units,
    leases,
    tenants,
  };
}

/**
 * Compare le snapshot PlexFlow avec la DB locale et renvoie les écarts.
 * Si PlexFlow n'est pas configuré: { configured: false, error }.
 */
async function compareWithLocal(buildingId) {
  const snapshot = await getFullSnapshot(buildingId);
  if (!snapshot.configured) {
    return { configured: false, error: snapshot.error || 'PlexFlow indisponible' };
  }

  const localBuilding = await findLocalBuilding(buildingId);
  const localBuildingId = localBuilding ? localBuilding.id : null;

  let localUnits = [];
  let localLeaseRows = [];
  if (localBuildingId) {
    localUnits = await db
      .select()
      .from(unitsTable)
      .where(and(eq(unitsTable.buildingId, localBuildingId), eq(unitsTable.isActive, true)));

    localLeaseRows = await db
      .select({ lease: leasesTable, unitLabel: unitsTable.label })
      .from(leasesTable)
      .innerJoin(unitsTable, eq(leasesTable.unitId, unitsTable.id))
      .where(and(eq(unitsTable.buildingId, localBuildingId), eq(leasesTable.isActive, true)));
  }

  // Index des enregistrements locaux (par plexflowId puis par label/clé).
  const localUnitPlexIds = new Set();
  const localUnitLabels = new Set();
  for (const unit of localUnits) {
    const pid = jsonField(unit.amenities, 'plexflowId');
    if (pid !== undefined) { localUnitPlexIds.add(String(pid)); }
    if (unit.label) { localUnitLabels.add(normLabel(unit.label)); }
  }

  const localLeasePlexIds = new Set();
  const localLeaseKeys = new Set();
  for (const row of localLeaseRows) {
    const pid = jsonField(row.lease.terms, 'plexflowId');
    if (pid !== undefined) { localLeasePlexIds.add(String(pid)); }
    localLeaseKeys.add(leaseKey(row.unitLabel, `${row.lease.tenantFirstName} ${row.lease.tenantLastName}`));
  }

  // ── Unités manquantes ──
  const missingUnits = [];
  for (const unit of snapshot.units) {
    const pid = plexUnitId(unit);
    const label = plexUnitLabel(unit);
    const known = (pid !== undefined && localUnitPlexIds.has(String(pid)))
      || (label && localUnitLabels.has(normLabel(label)));
    if (!known) {
      missingUnits.push({
        plexflowId: pid !== undefined ? String(pid) : null,
        label: label || null,
        floor: pick(unit, ['floor', 'level']) ?? null,
        rooms: pick(unit, ['rooms', 'bedrooms', 'numberOfRooms']) ?? null,
        rent: numOrNull(pick(unit, ['rent', 'rentAmount', 'monthlyRent'])),
        bedrooms: pick(unit, ['bedrooms', 'rooms']) ?? null,
        bathrooms: pick(unit, ['bathrooms']) ?? null,
      });
    }
  }

  // ── Baux manquants ──
  const missingLeases = [];
  for (const lease of snapshot.leases) {
    const pid = plexLeaseId(lease);
    const tenantName = fullName(lease) || null;
    const unitLabel = lease._unitLabel || pick(lease, ['unitLabel', 'unit']) || null;
    const known = (pid !== undefined && localLeasePlexIds.has(String(pid)))
      || localLeaseKeys.has(leaseKey(unitLabel, tenantName));
    if (!known) {
      missingLeases.push({
        plexflowId: pid !== undefined ? String(pid) : null,
        unitPlexflowId: lease._unitPlexflowId !== undefined ? String(lease._unitPlexflowId) : null,
        unitLabel,
        tenantName,
        rent: numOrNull(pick(lease, ['rent', 'rentAmount', 'monthlyRent'])),
        startDate: pick(lease, ['startDate', 'start', 'beginDate']) ?? null,
        endDate: pick(lease, ['endDate', 'end', 'expiryDate']) ?? null,
      });
    }
  }

  // ── Locataires manquants ── (présent localement = unité du même label déjà
  // occupée par un tenant du même nom)
  const missingTenants = [];
  for (const tenant of snapshot.tenants) {
    const pid = plexTenantId(tenant);
    const name = fullName(tenant) || null;
    const unitLabel = tenant._unitLabel || null;
    const localUnit = localUnits.find((u) => u.label && normLabel(u.label) === normLabel(unitLabel || ''));
    const known = Boolean(localUnit && localUnit.tenantName && name
      && normLabel(localUnit.tenantName) === normLabel(name));
    if (!known) {
      missingTenants.push({
        plexflowId: pid !== undefined ? String(pid) : null,
        name,
        phone: pick(tenant, ['phone', 'phoneNumber', 'mobile']) ?? null,
        email: pick(tenant, ['email']) ?? null,
        unitLabel,
      });
    }
  }

  // ── En trop dans ImmoGestion (sans contrepartie PlexFlow) ──
  const plexUnitIds = new Set();
  const plexUnitLabels = new Set();
  for (const unit of snapshot.units) {
    const pid = plexUnitId(unit);
    if (pid !== undefined) { plexUnitIds.add(String(pid)); }
    const label = plexUnitLabel(unit);
    if (label) { plexUnitLabels.add(normLabel(label)); }
  }
  const plexLeaseIds = new Set();
  const plexLeaseKeys = new Set();
  for (const lease of snapshot.leases) {
    const pid = plexLeaseId(lease);
    if (pid !== undefined) { plexLeaseIds.add(String(pid)); }
    plexLeaseKeys.add(leaseKey(lease._unitLabel, fullName(lease)));
  }

  const extraInLocal = [];
  for (const unit of localUnits) {
    const pid = jsonField(unit.amenities, 'plexflowId');
    const inPlex = (pid !== undefined && plexUnitIds.has(String(pid)))
      || (unit.label && plexUnitLabels.has(normLabel(unit.label)));
    if (!inPlex) {
      extraInLocal.push({ type: 'unit', id: unit.id, label: unit.label });
    }
  }
  for (const row of localLeaseRows) {
    const pid = jsonField(row.lease.terms, 'plexflowId');
    const key = leaseKey(row.unitLabel, `${row.lease.tenantFirstName} ${row.lease.tenantLastName}`);
    const inPlex = (pid !== undefined && plexLeaseIds.has(String(pid))) || plexLeaseKeys.has(key);
    if (!inPlex) {
      extraInLocal.push({
        type: 'lease',
        id: row.lease.id,
        label: `${row.lease.tenantFirstName} ${row.lease.tenantLastName}`.trim(),
      });
    }
  }

  const totalInPlexflow = snapshot.units.length + snapshot.leases.length + snapshot.tenants.length;
  const totalInLocal = localUnits.length + localLeaseRows.length;
  const missingCount = missingUnits.length + missingLeases.length + missingTenants.length;

  return {
    configured: true,
    buildingId,
    buildingName: snapshot.buildingName || (localBuilding ? localBuilding.name : null),
    localBuildingId,
    buildingInfo: snapshot.buildingInfo,
    missingUnits,
    missingLeases,
    missingTenants,
    extraInLocal,
    summary: {
      totalInPlexflow,
      totalInLocal,
      missingCount,
      extraCount: extraInLocal.length,
    },
  };
}

module.exports = {
  isConfigured,
  getBuildings,
  getUnits,
  getLeases,
  getTenants,
  syncAll,
  getFullSnapshot,
  compareWithLocal,
  findLocalBuilding,
  // helpers réutilisés par le service d'ingestion
  normLabel,
  pick,
};
