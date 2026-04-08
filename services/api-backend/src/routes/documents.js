import express from 'express';
import { documentController } from '../controllers/documentController.js';
import { validateRequest } from '../middleware/validation.js';
import { auth } from '../middleware/auth.js';
import { documentSchema } from '../models/document.js';

const router = express.Router();

/**
 * @swagger
 * components:
 *   schemas:
 *     Document:
 *       type: object
 *       properties:
 *         id:
 *           type: string
 *         name:
 *           type: string
 *         type:
 *           type: string
 *           enum: [lease, application, id, incomeProof, other]
 *         category:
 *           type: string
 *         fileSize:
 *           type: number
 *         mimeType:
 *           type: string
 *         url:
 *           type: string
 *         status:
 *           type: string
 *           enum: [pending, approved, rejected]
 *         referenceId:
 *           type: string
 *         metadata:
 *           type: object
 *         uploadedBy:
 *           type: string
 *         uploadedAt:
 *           type: string, format: date-time
 *         updatedAt:
 *           type: string, format: date-time
 */

/**
 * @swagger
 * /api/documents:
 *   get:
 *     summary: Get all documents
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [lease, application, id, incomeProof, other]
 *         description: Filter by document type
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *         description: Filter by category
 *       - in: query
 *         name: referenceId
 *         schema:
 *           type: string
 *         description: Filter by reference ID
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, approved, rejected]
 *         description: Filter by status
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         description: Page number
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         description: Number of items per page
 *     responses:
 *       200:
 *         description: Documents retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 documents:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Document'
 *                 total:
 *                   type: number
 *                 page:
 *                   type: number
 *                 limit:
 *                   type: number
 */
router.get('/', auth, documentController.getAllDocuments);

/**
 * @swagger
 * /api/documents/{id}:
 *   get:
 *     summary: Get document by ID
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Document ID
 *     responses:
 *       200:
 *         description: Document retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 document:
 *                   $ref: '#/components/schemas/Document'
 */
router.get('/:id', auth, documentController.getDocumentById);

/**
 * @swagger
 * /api/documents/upload:
 *   post:
 *     summary: Upload document
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     consumes:
 *       multipart/form-data
 *     parameters:
 *       - in: formData
 *         name: file
 *         required: true
 *         type: string
 *         format: binary
 *       - in: formData
 *         name: type
 *         required: true
 *         schema:
 *           type: string
 *           enum: [lease, application, id, incomeProof, other]
 *       - in: formData
 *         name: category
 *         schema:
 *           type: string
 *       - in: formData
 *         name: referenceId
 *         schema:
 *           type: string
 *       - in: formData
 *         name: metadata
 *         schema:
 *           type: string
 *     responses:
 *       201:
 *         description: Document uploaded successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 document:
 *                   $ref: '#/components/schemas/Document'
 */
router.post('/upload', auth, documentController.uploadDocument);

/**
 * @swagger
 * /api/documents:
 *   post:
 *     summary: Create document record (external file)
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - url
 *               - type
 *             properties:
 *               name:
 *                 type: string
 *               url:
 *                 type: string
 *               type:
 *                 type: string
 *                 enum: [lease, application, id, incomeProof, other]
 *               category:
 *                 type: string
 *               metadata:
 *                 type: object
 *     responses:
 *       201:
 *         description: Document created successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 document:
 *                   $ref: '#/components/schemas/Document'
 */
router.post('/', auth, validateRequest(documentSchema), documentController.createDocument);

/**
 * @swagger
 * /api/documents/{id}:
 *   put:
 *     summary: Update document
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Document ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               category:
 *                 type: string
 *               status:
 *                 type: string
 *                 enum: [pending, approved, rejected]
 *               metadata:
 *                 type: object
 *     responses:
 *       200:
 *         description: Document updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 document:
 *                   $ref: '#/components/schemas/Document'
 */
router.put('/:id', auth, validateRequest(documentSchema), documentController.updateDocument);

/**
 * @swagger
 * /api/documents/{id}/status:
 *   patch:
 *     summary: Update document status
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *           required: true
 *           schema:
 *             type: string
 *           description: Document ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [pending, approved, rejected]
 *               notes:
 *                 type: string
 *     responses:
 *       200:
 *         description: Document status updated successfully
 */
router.patch('/:id/status', auth, documentController.updateDocumentStatus);

/**
 * @swagger
 * /api/documents/{id}:
 *   delete:
 *     summary: Delete document
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Document ID
 *     responses:
 *       200:
 *         description: Document deleted successfully
 */
router.delete('/:id', auth, documentController.deleteDocument);

/**
 * @swagger
 * /api/documents/{id}/download:
 *   get:
 *     summary: Download document
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *           schema:
 *             type: string
 *           description: Document ID
 *     responses:
 *       200:
 *         description: File download initiated
 *         content:
 *           application/octet-stream:
 *     responses:
 *       404:
 *         description: Document not found
 */
router.get('/:id/download', auth, documentController.downloadDocument);

/**
 * @swagger
 * /api/documents/{id}/share:
 *   post:
 *     summary: Share document
 *     tags: [Documents]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Document ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string, format: email
 *               message:
 *                 type: string
 *     responses:
 *       200:
 *         description: Document shared successfully
 */
router.post('/:id/share', auth, documentController.shareDocument);

export default router;