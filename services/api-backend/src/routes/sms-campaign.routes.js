const express = require('express');

const router = express.Router();
const smsCampaignController = require('../controllers/sms-campaign.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

// ─── SMS Templates (authenticated) ───
router.post('/templates', authenticateToken, asyncHandler(smsCampaignController.createTemplateHandler));
router.get('/templates', authenticateToken, asyncHandler(smsCampaignController.getTemplatesHandler));
router.get('/templates/preview', authenticateToken, asyncHandler(smsCampaignController.previewTemplateHandler));
router.get('/templates/:id', authenticateToken, asyncHandler(smsCampaignController.getTemplateByIdHandler));
router.patch('/templates/:id', authenticateToken, asyncHandler(smsCampaignController.updateTemplateHandler));
router.delete('/templates/:id', authenticateToken, asyncHandler(smsCampaignController.deleteTemplateHandler));

// ─── SMS Campaigns (authenticated) ───
router.post('/campaigns', authenticateToken, asyncHandler(smsCampaignController.createCampaignHandler));
router.get('/campaigns', authenticateToken, asyncHandler(smsCampaignController.getCampaignsHandler));
router.get('/campaigns/:id', authenticateToken, asyncHandler(smsCampaignController.getCampaignByIdHandler));
router.patch('/campaigns/:id', authenticateToken, asyncHandler(smsCampaignController.updateCampaignHandler));
router.delete('/campaigns/:id', authenticateToken, asyncHandler(smsCampaignController.deleteCampaignHandler));
router.post('/campaigns/:id/activate', authenticateToken, asyncHandler(smsCampaignController.activateCampaignHandler));
router.post('/campaigns/:id/execute', authenticateToken, asyncHandler(smsCampaignController.executeCampaignHandler));

module.exports = router;
