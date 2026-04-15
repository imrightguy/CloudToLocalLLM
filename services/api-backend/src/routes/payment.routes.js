const express = require('express');

const router = express.Router();
const paymentController = require('../controllers/payment.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');

/**
 * @swagger
 * /api/payments:
 *   get:
 *     tags: [Payments]
 *     summary: List all payments
 *     description: Returns a paginated list of payments with optional filtering.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, paid, late, partial]
 *       - in: query
 *         name: leaseId
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: buildingId
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: List of payments
 */
router.get('/', authenticateToken, asyncHandler(paymentController.getPayments));

/**
 * @swagger
 * /api/payments/late:
 *   get:
 *     tags: [Payments]
 *     summary: Get late payments
 *     description: Returns all late payments with total late fees summary.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: leaseId
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: buildingId
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Late payments
 */
router.get('/late', authenticateToken, asyncHandler(paymentController.getLatePayments));

/**
 * @swagger
 * /api/payments/lease/{id}:
 *   get:
 *     tags: [Payments]
 *     summary: Get payments by lease
 *     description: Returns all payments for a specific lease. Auto-updates overdue payment statuses.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Payments for lease
 */
router.get('/lease/:id', authenticateToken, asyncHandler(paymentController.getPaymentsByLease));

/**
 * @swagger
 * /api/payments/lease/{id}/late-fee-preview:
 *   get:
 *     tags: [Payments]
 *     summary: Preview late fee for a lease
 *     description: Calculate what the late fee would be today for a given lease.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Late fee preview
 */
router.get('/lease/:id/late-fee-preview', authenticateToken, asyncHandler(paymentController.calculateLateFeePreview));

/**
 * @swagger
 * /api/payments:
 *   post:
 *     tags: [Payments]
 *     summary: Create a payment
 *     description: Create a new rent payment record. Auto-calculates late fee if past due.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - leaseId
 *               - amount
 *               - dueDate
 *             properties:
 *               leaseId:
 *                 type: string
 *                 format: uuid
 *               amount:
 *                 type: number
 *                 example: 1200
 *               dueDate:
 *                 type: string
 *                 format: date
 *               method:
 *                 type: string
 *                 enum: [check, transfer, cash, interac, auto_debit]
 *               reference:
 *                 type: string
 *               notes:
 *                 type: string
 *     responses:
 *       201:
 *         description: Payment created
 */
router.post('/', authenticateToken, asyncHandler(paymentController.createPayment));

/**
 * @swagger
 * /api/payments/{id}:
 *   get:
 *     tags: [Payments]
 *     summary: Get payment by ID
 *     description: Returns a single payment with lease, unit, and building details.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Payment details
 *       404:
 *         description: Payment not found
 */
router.get('/:id', authenticateToken, asyncHandler(paymentController.getPaymentById));

/**
 * @swagger
 * /api/payments/{id}:
 *   patch:
 *     tags: [Payments]
 *     summary: Update a payment
 *     description: Update payment details. Cannot update a paid payment.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               amount:
 *                 type: number
 *               paidDate:
 *                 type: string
 *                 format: date
 *               method:
 *                 type: string
 *                 enum: [check, transfer, cash, interac, auto_debit]
 *               reference:
 *                 type: string
 *               notes:
 *                 type: string
 *     responses:
 *       200:
 *         description: Payment updated
 */
router.patch('/:id', authenticateToken, asyncHandler(paymentController.updatePayment));

/**
 * @swagger
 * /api/payments/{id}:
 *   delete:
 *     tags: [Payments]
 *     summary: Delete a payment
 *     description: Soft delete a payment. Cannot delete a paid payment.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Payment deleted
 */
router.delete('/:id', authenticateToken, asyncHandler(paymentController.deletePayment));

/**
 * @swagger
 * /api/payments/{id}/status:
 *   patch:
 *     tags: [Payments]
 *     summary: Update payment status
 *     description: Change payment status (e.g. mark as paid).
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
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
 *                 enum: [pending, paid, late, partial]
 *     responses:
 *       200:
 *         description: Payment status updated
 */
router.patch('/:id/status', authenticateToken, asyncHandler(paymentController.updatePaymentStatus));

module.exports = router;
