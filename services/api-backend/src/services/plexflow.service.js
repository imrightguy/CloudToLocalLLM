const { eq, and, sql } = require('drizzle-orm');
const { cache, invalidate } = require('../utils/cache');
const logger = require('../utils/logger');
const { db } = require('../database/connection');
const { buildingsTable, unitsTable, leasesTable } = require('../database/schema');

const CACHE_TTL_SECONDS = 3600;
const REQUEST_TIMEOUT_MS = 8000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// ─────────────────────────────────────────────────────────────────────────────
//  API PlexFlow réelle
//
//  PlexFlow n'expose qu'UN SEUL endpoint REST public:
//      GET /property/vacant-units   (auth via en-tête X-Plexflow-Key)
//
//  Chaque unité retournée porte ~38 champs. Les bâtiments, unités, baux et
//  locataires sont TOUS dérivés de cette réponse — il n'existe pas de
//  /buildings, /units ni /leases côté PlexFlow.
//
//  Les montants sont EN CENTS (currentRentTotalCents 84500 = 845,00 $) et sont
//  convertis en dollars ici, une fois, avant de quitter le service.
// ─────────────────────────────────────────────────────────────────────────────

const VACANT_UNITS_PATH = '/property/vacant-units';
const VACANT_UNITS_CACHE_KEY = 'plexflow:vacant-units';

function isConfigured() {
  return Boolean(process.env.PLEXFLOW_API_URL);
}

function asArray(raw) {
  if (Array.isArray(raw)) {
    return raw;
  }
  if (raw && typeof raw === 'object') {
    for (const key of ['data', 'units', 'vacantUnits', 'results']) {
      if (Array.isArray(raw[key])) {
        return raw[key];
      }
    }
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

/**
 * Récupère (et met en cache) la liste brute des unités vacantes PlexFlow.
 * Source unique de toutes les données PlexFlow exposées par ce service.
 */
async function getVacantUnits() {
  const cached = cache.get(VACANT_UNITS_CACHE_KEY);
  if (cached !== undefined) {
    return cached;
  }
  const raw = await plexflowGet(VACANT_UNITS_PATH);
  if (raw === null) {
    // Échec/timeout de l'API PlexFlow: ne pas cacher pour éviter de figer
    // des données vides pendant tout le TTL. On réessaiera au prochain appel.
    return [];
  }
  const data = asArray(raw);
  cache.set(VACANT_UNITS_CACHE_KEY, data, CACHE_TTL_SECONDS);
  return data;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers d'extraction / normalisation
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

// Convertit un montant en cents (PlexFlow) vers des dollars. null si absent/invalide.
function centsToAmount(cents) {
  if (cents === undefined || cents === null || cents === '') {
    return null;
  }
  const n = Number(cents);
  return Number.isFinite(n) ? n / 100 : null;
}

// Valeur d'affichage (string) ou null.
function asLabel(value) {
  return value === undefined || value === null || value === '' ? null : String(value);
}

// Nom complet à partir d'un champ direct ou de prénom/nom séparés.
function fullName(obj) {
  if (typeof obj === 'string') {
    return obj.trim() || undefined;
  }
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
 * Normalise un bâtiment à partir d'une unité vacante PlexFlow.
 * Plusieurs unités partagent le même propertyId → un seul bâtiment.
 */
function normalizeBuilding(raw) {
  const id = pick(raw, ['propertyId']);
  return {
    id: asLabel(id),
    name: asLabel(pick(raw, ['propertyNickname', 'propertyAddress'])),
    address: asLabel(pick(raw, ['propertyAddress'])),
    addressDetails: asLabel(pick(raw, ['propertyAddressDetails'])),
  };
}

/**
 * Normalise une unité vacante PlexFlow vers une forme stable et en dollars.
 */
function normalizeUnit(raw) {
  return {
    id: asLabel(pick(raw, ['unitId'])),
    buildingId: asLabel(pick(raw, ['propertyId'])),
    label: asLabel(pick(raw, ['unitNickname', 'apptNb', 'unitAddress'])),
    apptNb: asLabel(pick(raw, ['apptNb'])),
    address: asLabel(pick(raw, ['unitAddress'])),
    floor: pick(raw, ['floorLevel']) ?? null,
    surfaceArea: pick(raw, ['surfaceArea']) ?? null,
    unitType: pick(raw, ['unitType']) ?? null,
    rentId: asLabel(pick(raw, ['rentId'])),
    rentStatus: pick(raw, ['rentStatus']) ?? null,
    // Montants convertis cents → dollars.
    rent: centsToAmount(raw && raw.currentRentTotalCents),
    scheduledRent: centsToAmount(raw && raw.scheduledRentTotalCents),
    rentBeforeDiscount: centsToAmount(raw && raw.rentBeforeDiscount),
    marketPrice: centsToAmount(raw && raw.marketPrice),
    marketRenewalPrice: centsToAmount(raw && raw.marketRenewalPrice),
    markedWontRenew: (raw && raw.markedWontRenew) ?? null,
    statuses: (raw && raw.statuses) ?? null,
    dateTenantLeaving: (raw && raw.dateTenantLeaving) ?? null,
    dateTenantEntering: (raw && raw.dateTenantEntering) ?? null,
    dateAvailableForMaintenance: (raw && raw.dateAvailableForMaintenance) ?? null,
    dateAvailableForRent: (raw && raw.dateAvailableForRent) ?? null,
    subaccount: (raw && raw.subaccount) ?? null,
  };
}

// Extrait des locataires (entrants/sortants) d'une unité vacante.
function extractTenants(raw, unit, directions) {
  const out = [];
  const add = (list, direction) => {
    if (!Array.isArray(list)) {
      return;
    }
    for (const t of list) {
      const name = fullName(t) || null;
      const isObj = t && typeof t === 'object';
      if (!name && !isObj) {
        continue;
      }
      out.push({
        id: isObj ? asLabel(pick(t, ['tenantId', 'id', '_id'])) : null,
        name,
        phone: isObj ? (pick(t, ['phone', 'phoneNumber', 'mobile']) ?? null) : null,
        email: isObj ? (pick(t, ['email']) ?? null) : null,
        direction,
        _unitId: unit.id,
        _unitLabel: unit.label,
      });
    }
  };
  if (directions.includes('entering')) {
    add(raw.tenantsEntering, 'entering');
  }
  if (directions.includes('leaving')) {
    add(raw.tenantsLeaving, 'leaving');
  }
  return out;
}

// Dérive un bail (locataire entrant) d'une unité vacante, s'il y en a un.
function leasesFromUnit(raw, unit) {
  const entering = Array.isArray(raw.tenantsEntering) ? raw.tenantsEntering : [];
  if (entering.length === 0) {
    return [];
  }
  const tenantName = entering.map((t) => fullName(t)).filter(Boolean).join(', ') || null;
  return [{
    id: unit.rentId,
    unitId: unit.id,
    unitLabel: unit.label,
    tenantName,
    rent: unit.scheduledRent ?? unit.rent,
    startDate: unit.dateTenantEntering,
    endDate: unit.dateTenantLeaving,
    status: unit.rentStatus,
  }];
}

// ─────────────────────────────────────────────────────────────────────────────
//  API publique du service — tout dérive de /property/vacant-units
// ─────────────────────────────────────────────────────────────────────────────

async function getBuildings() {
  const rawUnits = await getVacantUnits();
  const byId = new Map();
  for (const raw of rawUnits) {
    const building = normalizeBuilding(raw);
    if (building.id === null) {
      continue;
    }
    const existing = byId.get(building.id);
    if (existing) {
      existing.vacantUnitCount += 1;
    } else {
      byId.set(building.id, { ...building, vacantUnitCount: 1 });
    }
  }
  return Array.from(byId.values());
}

async function getUnits(buildingId) {
  const target = String(buildingId);
  const rawUnits = await getVacantUnits();
  return rawUnits
    .filter((raw) => asLabel(pick(raw, ['propertyId'])) === target)
    .map(normalizeUnit);
}

async function getLeases(unitId) {
  const target = String(unitId);
  const rawUnits = await getVacantUnits();
  const leases = [];
  for (const raw of rawUnits) {
    if (asLabel(pick(raw, ['unitId'])) !== target) {
      continue;
    }
    const unit = normalizeUnit(raw);
    leases.push(...leasesFromUnit(raw, unit));
  }
  return leases;
}

async function getTenants(unitId) {
  const target = String(unitId);
  const rawUnits = await getVacantUnits();
  const tenants = [];
  for (const raw of rawUnits) {
    if (asLabel(pick(raw, ['unitId'])) !== target) {
      continue;
    }
    const unit = normalizeUnit(raw);
    tenants.push(...extractTenants(raw, unit, ['entering', 'leaving']));
  }
  return tenants;
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
// ─────────────────────────────────────────────────────────────────────────────

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
 * Snapshot complet d'un bâtiment PlexFlow: building + units + leases + tenants,
 * dérivé entièrement de /property/vacant-units (filtré par propertyId).
 */
async function getFullSnapshot(buildingId) {
  if (!isConfigured()) {
    return { configured: false, error: 'PlexFlow indisponible' };
  }

  const target = String(buildingId);
  const all = await getVacantUnits();
  const rawUnits = all.filter((raw) => asLabel(pick(raw, ['propertyId'])) === target);
  const building = rawUnits.length > 0 ? normalizeBuilding(rawUnits[0]) : null;

  const units = [];
  const leases = [];
  const tenants = [];

  for (const raw of rawUnits) {
    const unit = normalizeUnit(raw);
    units.push(unit);
    leases.push(...leasesFromUnit(raw, unit));
    tenants.push(...extractTenants(raw, unit, ['entering']));
  }

  return {
    configured: true,
    buildingId,
    building,
    buildingName: building ? building.name : null,
    buildingInfo: building ? {
      name: building.name,
      address: building.address,
      addressDetails: building.addressDetails,
      city: null,
      province: null,
      postalCode: null,
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
    const pid = unit.id;
    const label = unit.label;
    const known = (pid !== null && localUnitPlexIds.has(String(pid)))
      || (label && localUnitLabels.has(normLabel(label)));
    if (!known) {
      missingUnits.push({
        plexflowId: pid !== null ? String(pid) : null,
        label: label || null,
        floor: unit.floor ?? null,
        rooms: null,
        rent: unit.rent ?? null,
        bedrooms: null,
        bathrooms: null,
        surfaceArea: unit.surfaceArea ?? null,
        unitType: unit.unitType ?? null,
      });
    }
  }

  // ── Baux manquants ──
  const missingLeases = [];
  for (const lease of snapshot.leases) {
    const pid = lease.id;
    const tenantName = lease.tenantName || null;
    const unitLabel = lease.unitLabel || null;
    const known = (pid !== null && pid !== undefined && localLeasePlexIds.has(String(pid)))
      || localLeaseKeys.has(leaseKey(unitLabel, tenantName));
    if (!known) {
      missingLeases.push({
        plexflowId: (pid !== null && pid !== undefined) ? String(pid) : null,
        unitPlexflowId: lease.unitId !== null && lease.unitId !== undefined ? String(lease.unitId) : null,
        unitLabel,
        tenantName,
        rent: lease.rent ?? null,
        startDate: lease.startDate ?? null,
        endDate: lease.endDate ?? null,
      });
    }
  }

  // ── Locataires manquants ── (présent localement = unité du même label déjà
  // occupée par un tenant du même nom)
  const missingTenants = [];
  for (const tenant of snapshot.tenants) {
    const pid = tenant.id;
    const name = tenant.name || null;
    const unitLabel = tenant._unitLabel || null;
    const localUnit = localUnits.find((u) => u.label && normLabel(u.label) === normLabel(unitLabel || ''));
    const known = Boolean(localUnit && localUnit.tenantName && name
      && normLabel(localUnit.tenantName) === normLabel(name));
    if (!known) {
      missingTenants.push({
        plexflowId: (pid !== null && pid !== undefined) ? String(pid) : null,
        name,
        phone: tenant.phone ?? null,
        email: tenant.email ?? null,
        unitLabel,
      });
    }
  }

  // ── En trop dans ImmoGestion (sans contrepartie PlexFlow) ──
  const plexUnitIds = new Set();
  const plexUnitLabels = new Set();
  for (const unit of snapshot.units) {
    if (unit.id !== null) { plexUnitIds.add(String(unit.id)); }
    if (unit.label) { plexUnitLabels.add(normLabel(unit.label)); }
  }
  const plexLeaseIds = new Set();
  const plexLeaseKeys = new Set();
  for (const lease of snapshot.leases) {
    if (lease.id !== null && lease.id !== undefined) { plexLeaseIds.add(String(lease.id)); }
    plexLeaseKeys.add(leaseKey(lease.unitLabel, lease.tenantName));
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
  getVacantUnits,
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
