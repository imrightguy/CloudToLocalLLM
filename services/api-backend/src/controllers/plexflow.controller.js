const plexflowService = require('../services/plexflow.service');
const { successResponse } = require('../utils/apiResponse');
const { child } = require('../utils/logger');

const log = child({ controller: 'plexflow' });

exports.getBuildings = async (req, res) => {
  try {
    const data = await plexflowService.getBuildings();
    return res.json(successResponse({ data, metadata: { configured: plexflowService.isConfigured() } }));
  } catch (error) {
    log.error('Error fetching PlexFlow buildings', { error: error.message });
    return res.status(502).json({
      success: false,
      error: { message: 'Échec de la lecture PlexFlow', code: 'PLEXFLOW_BUILDINGS_FAILED' },
    });
  }
};

exports.getUnits = async (req, res) => {
  try {
    const data = await plexflowService.getUnits(req.params.id);
    return res.json(successResponse({ data }));
  } catch (error) {
    log.error('Error fetching PlexFlow units', { error: error.message });
    return res.status(502).json({
      success: false,
      error: { message: 'Échec de la lecture PlexFlow', code: 'PLEXFLOW_UNITS_FAILED' },
    });
  }
};

exports.getLeases = async (req, res) => {
  try {
    const data = await plexflowService.getLeases(req.params.id);
    return res.json(successResponse({ data }));
  } catch (error) {
    log.error('Error fetching PlexFlow leases', { error: error.message });
    return res.status(502).json({
      success: false,
      error: { message: 'Échec de la lecture PlexFlow', code: 'PLEXFLOW_LEASES_FAILED' },
    });
  }
};

exports.getTenants = async (req, res) => {
  try {
    const data = await plexflowService.getTenants(req.params.id);
    return res.json(successResponse({ data }));
  } catch (error) {
    log.error('Error fetching PlexFlow tenants', { error: error.message });
    return res.status(502).json({
      success: false,
      error: { message: 'Échec de la lecture PlexFlow', code: 'PLEXFLOW_TENANTS_FAILED' },
    });
  }
};

exports.sync = async (req, res) => {
  try {
    const data = await plexflowService.syncAll();
    return res.json(successResponse({ data, message: 'Synchronisation PlexFlow déclenchée' }));
  } catch (error) {
    log.error('Error syncing PlexFlow', { error: error.message });
    return res.status(502).json({
      success: false,
      error: { message: 'Échec de la synchronisation PlexFlow', code: 'PLEXFLOW_SYNC_FAILED' },
    });
  }
};
