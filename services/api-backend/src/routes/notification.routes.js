const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const notificationController = require('../controllers/notification.controller');

router.get('/me/preferences', authenticateToken, asyncHandler(notificationController.getPreferences));
router.patch('/me/preferences', authenticateToken, asyncHandler(notificationController.updatePreferences));
router.get('/', authenticateToken, asyncHandler(notificationController.getNotifications));
router.get('/unread-count', authenticateToken, asyncHandler(notificationController.getUnreadCount));
router.patch('/read-all', authenticateToken, asyncHandler(notificationController.markAllAsRead));
router.patch('/:id/read', authenticateToken, asyncHandler(notificationController.markAsRead));

module.exports = router;
