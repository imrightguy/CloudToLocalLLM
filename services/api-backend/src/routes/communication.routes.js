const express = require('express');
const router = express.Router();
const communicationController = require('../controllers/communication.controller');
const { asyncHandler } = require('../utils/apiResponse');

// Communication log routes
router.get('/', asyncHandler(communicationController.getCommunications));
router.get('/logs', asyncHandler(communicationController.getCommunicationLogs));
router.get('/logs/:id', asyncHandler(communicationController.getCommunicationLogById));
router.put('/logs/:id', asyncHandler(communicationController.updateCommunicationLog));

// Email communication
router.post('/email', asyncHandler(communicationController.sendEmail));
router.get('/email/templates', asyncHandler(communicationController.getEmailTemplates));
router.post('/email/templates', asyncHandler(communicationController.createEmailTemplate));

// SMS communication
router.post('/sms', asyncHandler(communicationController.sendSMS));
router.get('/sms/templates', asyncHandler(communicationController.getSmsTemplates));
router.post('/sms/templates', asyncHandler(communicationController.createSmsTemplate));

// Phone communication
router.post('/phone', asyncHandler(communicationController.recordPhoneCall));
router.get('/phone/calls', asyncHandler(communicationController.getPhoneCalls));

// Facebook communication
router.post('/fb', asyncHandler(communicationController.sendFacebookMessage));
router.get('/fb/templates', asyncHandler(communicationController.getFacebookTemplates));

// Communication templates
router.get('/templates', asyncHandler(communicationController.getTemplates));
router.post('/templates', asyncHandler(communicationController.createTemplate));

// Communication search
router.get('/search', asyncHandler(communicationController.searchCommunications));

// Communication bulk operations
router.post('/bulk', asyncHandler(communicationController.sendBulkCommunication));

module.exports = router;