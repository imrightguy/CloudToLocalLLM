const DEMO_MARKETPLACE_TAG = '__DEMO_SEED__';
const SEEDED_MODE_VALUES = new Set(['seeded', 'demo', 'mock']);

function getMarketplaceDataMode() {
  return String(
    process.env.MARKETPLACE_DATA_MODE
      || process.env.DEMO_MARKETPLACE_DATA_MODE
      || 'live',
  ).trim().toLowerCase();
}

function isSeededMarketplaceMode() {
  return SEEDED_MODE_VALUES.has(getMarketplaceDataMode());
}

function isDemoMarketplaceLead(lead) {
  if (!lead || !lead.tags) {
    return false;
  }

  if (Array.isArray(lead.tags)) {
    return lead.tags.includes(DEMO_MARKETPLACE_TAG);
  }

  if (typeof lead.tags === 'object') {
    return lead.tags[DEMO_MARKETPLACE_TAG] === true || lead.tags[DEMO_MARKETPLACE_TAG] === 'true';
  }

  return false;
}

module.exports = {
  DEMO_MARKETPLACE_TAG,
  getMarketplaceDataMode,
  isSeededMarketplaceMode,
  isDemoMarketplaceLead,
};
