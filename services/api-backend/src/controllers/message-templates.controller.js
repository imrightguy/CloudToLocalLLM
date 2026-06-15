const messageTemplatesService = require('../services/message-templates.service');
const { child } = require('../utils/logger');

const log = child({ controller: 'message-templates' });

// GET /api/message-templates
exports.list = async (req, res) => {
  try {
    const templates = await messageTemplatesService.listTemplates();
    return res.json({ success: true, data: templates });
  } catch (error) {
    log.error('Error listing message templates', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'MESSAGE_TEMPLATES_FETCH_FAILED' },
    });
  }
};

// PUT /api/message-templates/:eventType
exports.update = async (req, res) => {
  try {
    const template = await messageTemplatesService.upsertTemplate(req.params.eventType, req.body);
    return res.json({ success: true, data: template, message: 'Modèle enregistré' });
  } catch (error) {
    if (error.code === 'INVALID_EVENT_TYPE') {
      return res.status(400).json({
        success: false,
        error: { message: 'Type d\'événement invalide', code: 'INVALID_EVENT_TYPE' },
      });
    }
    log.error('Error updating message template', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'MESSAGE_TEMPLATE_UPDATE_FAILED' },
    });
  }
};
