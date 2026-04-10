const express = require('express');

const router = express.Router();
const documentController = require('../controllers/document.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

router.get('/', authenticateToken, asyncHandler(documentController.getDocuments));
router.post('/', authenticateToken, asyncHandler(documentController.uploadDocument));
router.get('/search', authenticateToken, asyncHandler(documentController.searchDocuments));
router.get('/:id', authenticateToken, asyncHandler(documentController.getDocumentById));
router.put('/:id', authenticateToken, asyncHandler(documentController.updateDocument));
router.delete('/:id', authenticateToken, asyncHandler(documentController.deleteDocument));
router.put('/:id/approve', authenticateToken, asyncHandler(documentController.approveDocument));
router.put('/:id/reject', authenticateToken, asyncHandler(documentController.rejectDocument));

module.exports = router;
