const express = require('express');
const router = express.Router();
const documentController = require('../controllers/document.controller');
const { asyncHandler } = require('../utils/apiResponse');

// Document routes
router.get('/', asyncHandler(documentController.getDocuments));
router.post('/', asyncHandler(documentController.uploadDocument));
router.get('/:id', asyncHandler(documentController.getDocumentById));
router.put('/:id', asyncHandler(documentController.updateDocument));
router.delete('/:id', asyncHandler(documentController.deleteDocument));

// Document search
router.get('/search', asyncHandler(documentController.searchDocuments));

// Document approval
router.put('/:id/approve', asyncHandler(documentController.approveDocument));
router.put('/:id/reject', asyncHandler(documentController.rejectDocument));

// Document sharing
router.post('/:id/share', asyncHandler(documentController.shareDocument));
router.post('/:id/download', asyncHandler(documentController.downloadDocument));

// Document bulk operations
router.post('/bulk', asyncHandler(documentController.bulkUpdateDocuments));

// Document categories
router.get('/categories', asyncHandler(documentController.getDocumentCategories));

module.exports = router;