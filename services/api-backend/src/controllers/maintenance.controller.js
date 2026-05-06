const { getMaintenanceCommandCenter } = require('../services/maintenance-command-center.service');
const { child } = require('../utils/logger');

const log = child({ controller: 'maintenance' });

exports.getCommandCenter = async (req, res) => {
  try {
    const { buildingId = null, limit = 12 } = req.query;
    const data = await getMaintenanceCommandCenter({ buildingId, limit });

    return res.json({
      success: true,
      data,
      message: 'Tableau de bord de maintenance récupéré avec succès',
    });
  } catch (error) {
    log.error('Error fetching maintenance command center', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'MAINTENANCE_COMMAND_CENTER_FAILED' },
    });
  }
};
