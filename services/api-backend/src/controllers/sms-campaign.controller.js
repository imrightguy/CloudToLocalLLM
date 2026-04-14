const { child } = require('../utils/logger');
const {
  createTemplate,
  getTemplates,
  getTemplateById,
  updateTemplate,
  deleteTemplate,
  createCampaign,
  getCampaigns,
  getCampaignById,
  updateCampaign,
  setCampaignStatus,
  deleteCampaign,
  executeCampaign,
  renderTemplate,
} = require('../services/sms.service');
const {
  templateSchema,
  updateTemplateSchema,
  campaignSchema,
  updateCampaignSchema,
  activateCampaignSchema,
} = require('../models/sms-campaign');

const log = child({ controller: 'sms-campaign' });

const createTemplateHandler = async (req, res) => {
  try {
    const { error, value } = templateSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const template = await createTemplate(value);
    res.status(201).json({ success: true, data: template, message: 'Template created successfully' });
  } catch (error) {
    log.error('Error creating template', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'TEMPLATE_CREATION_FAILED' },
    });
  }
};

const getTemplatesHandler = async (req, res) => {
  try {
    const { category, language } = req.query;
    const filters = {};
    if (category) filters.category = category;
    if (language) filters.language = language;

    const templates = await getTemplates(filters);
    res.json({ success: true, data: templates });
  } catch (error) {
    log.error('Error fetching templates', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'TEMPLATE_FETCH_FAILED' },
    });
  }
};

const getTemplateByIdHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const template = await getTemplateById(id);

    if (!template) {
      return res.status(404).json({
        success: false,
        error: { message: 'Template not found', code: 'TEMPLATE_NOT_FOUND' },
      });
    }

    res.json({ success: true, data: template });
  } catch (error) {
    log.error('Error fetching template', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'TEMPLATE_FETCH_FAILED' },
    });
  }
};

const updateTemplateHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = updateTemplateSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await getTemplateById(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Template not found', code: 'TEMPLATE_NOT_FOUND' },
      });
    }

    const updated = await updateTemplate(id, value);
    res.json({ success: true, data: updated, message: 'Template updated successfully' });
  } catch (error) {
    log.error('Error updating template', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'TEMPLATE_UPDATE_FAILED' },
    });
  }
};

const deleteTemplateHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const existing = await getTemplateById(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Template not found', code: 'TEMPLATE_NOT_FOUND' },
      });
    }

    await deleteTemplate(id);
    res.json({ success: true, message: 'Template deleted successfully' });
  } catch (error) {
    log.error('Error deleting template', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'TEMPLATE_DELETE_FAILED' },
    });
  }
};

const previewTemplateHandler = async (req, res) => {
  try {
    const { body, variables } = req.body;
    if (!body) {
      return res.status(400).json({
        success: false,
        error: { message: 'Template body is required', code: 'VALIDATION_ERROR' },
      });
    }

    const rendered = renderTemplate(body, variables || {});
    res.json({ success: true, data: { rendered } });
  } catch (error) {
    log.error('Error previewing template', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'TEMPLATE_PREVIEW_FAILED' },
    });
  }
};

const createCampaignHandler = async (req, res) => {
  try {
    const { error, value } = campaignSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const campaign = await createCampaign(value, req.user?.id || null);
    res.status(201).json({ success: true, data: campaign, message: 'Campaign created successfully' });
  } catch (error) {
    log.error('Error creating campaign', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'CAMPAIGN_CREATION_FAILED' },
    });
  }
};

const getCampaignsHandler = async (req, res) => {
  try {
    const { status, targetAudience, buildingId } = req.query;
    const filters = {};
    if (status) filters.status = status;
    if (targetAudience) filters.targetAudience = targetAudience;
    if (buildingId) filters.buildingId = buildingId;

    const campaigns = await getCampaigns(filters);
    res.json({ success: true, data: campaigns });
  } catch (error) {
    log.error('Error fetching campaigns', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'CAMPAIGN_FETCH_FAILED' },
    });
  }
};

const getCampaignByIdHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const campaign = await getCampaignById(id);

    if (!campaign) {
      return res.status(404).json({
        success: false,
        error: { message: 'Campaign not found', code: 'CAMPAIGN_NOT_FOUND' },
      });
    }

    res.json({ success: true, data: campaign });
  } catch (error) {
    log.error('Error fetching campaign', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'CAMPAIGN_FETCH_FAILED' },
    });
  }
};

const updateCampaignHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = updateCampaignSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await getCampaignById(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Campaign not found', code: 'CAMPAIGN_NOT_FOUND' },
      });
    }

    if (existing.status === 'completed' || existing.status === 'cancelled') {
      return res.status(400).json({
        success: false,
        error: { message: `Cannot update a ${existing.status} campaign`, code: 'CAMPAIGN_FINALIZED' },
      });
    }

    const updated = await updateCampaign(id, value);
    res.json({ success: true, data: updated, message: 'Campaign updated successfully' });
  } catch (error) {
    log.error('Error updating campaign', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'CAMPAIGN_UPDATE_FAILED' },
    });
  }
};

const activateCampaignHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const { error, value } = activateCampaignSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        success: false,
        error: { message: error.details[0].message, code: 'VALIDATION_ERROR' },
      });
    }

    const existing = await getCampaignById(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Campaign not found', code: 'CAMPAIGN_NOT_FOUND' },
      });
    }

    const updated = await setCampaignStatus(id, value.status);
    res.json({ success: true, data: updated, message: `Campaign ${value.status}` });
  } catch (error) {
    log.error('Error activating campaign', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'CAMPAIGN_ACTIVATE_FAILED' },
    });
  }
};

const executeCampaignHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const existing = await getCampaignById(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Campaign not found', code: 'CAMPAIGN_NOT_FOUND' },
      });
    }

    const result = await executeCampaign(id);
    res.json({ success: true, data: result, message: `Campaign execution: ${result.processed} messages queued` });
  } catch (error) {
    log.error('Error executing campaign', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'CAMPAIGN_EXECUTE_FAILED' },
    });
  }
};

const deleteCampaignHandler = async (req, res) => {
  try {
    const { id } = req.params;
    const existing = await getCampaignById(id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Campaign not found', code: 'CAMPAIGN_NOT_FOUND' },
      });
    }

    await deleteCampaign(id);
    res.json({ success: true, message: 'Campaign deleted successfully' });
  } catch (error) {
    log.error('Error deleting campaign', { error: error.message });
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'CAMPAIGN_DELETE_FAILED' },
    });
  }
};

module.exports = {
  createTemplateHandler,
  getTemplatesHandler,
  getTemplateByIdHandler,
  updateTemplateHandler,
  deleteTemplateHandler,
  previewTemplateHandler,
  createCampaignHandler,
  getCampaignsHandler,
  getCampaignByIdHandler,
  updateCampaignHandler,
  activateCampaignHandler,
  executeCampaignHandler,
  deleteCampaignHandler,
};
