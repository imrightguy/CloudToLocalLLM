const express = require('express');

const router = express.Router();
const authController = require('../controllers/auth.controller');
const {
  authenticateToken,
  authorizeRole,
  optionalAuth,
} = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

// Public routes
router.post('/register', asyncHandler(authController.register));
router.post('/login', asyncHandler(authController.login));
router.post('/refresh', asyncHandler(authController.refreshAccessToken));
router.post('/logout', optionalAuth, asyncHandler(authController.logout));

// Protected routes (require authentication)
router.get('/profile', authenticateToken, asyncHandler(authController.getProfile));
router.put('/profile', authenticateToken, asyncHandler(authController.updateProfile));
router.put('/password', authenticateToken, asyncHandler(authController.changePassword));

// Admin routes
router.get('/users', authenticateToken, authorizeRole(['admin']), asyncHandler(authController.getAllUsers));
router.get('/users/:id', authenticateToken, authorizeRole(['admin']), asyncHandler(authController.getUserById));
router.put('/users/:id', authenticateToken, authorizeRole(['admin']), asyncHandler(authController.updateUser));
router.delete('/users/:id', authenticateToken, authorizeRole(['admin']), asyncHandler(authController.deleteUser));

module.exports = router;
