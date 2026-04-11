const express = require('express');

const router = express.Router();
const communicationController = require('../controllers/communication.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

router.get('/', authenticateToken, asyncHandler(communicationController.getCommunications));
router.get('/activity', authenticateToken, asyncHandler(communicationController.getActivityFeed));
router.post('/', authenticateToken, asyncHandler(communicationController.logCommunication));
router.get('/logs', authenticateToken, asyncHandler(communicationController.getCommunicationLogs));
router.get('/logs/:id', authenticateToken, asyncHandler(communicationController.getCommunicationLogById));

module.exports = router;
