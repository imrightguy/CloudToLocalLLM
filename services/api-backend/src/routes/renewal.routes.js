const express = require('express');

const router = express.Router();
const renewalController = require('../controllers/renewal.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { renewalSchemas, uuidParam } = require('../config/validation-schemas');

/**
 * @swagger
 * /api/renewals/expiring:
 *   get:
 *     tags: [Renewals]
 *     summary: Get leases needing renewal
 *     description: Returns active leases expiring within the specified window with renewal status.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: window
 *         schema:
 *           type: integer
 *           default: 90
 *         description: Days window to look ahead
 *     responses:
 *       200:
 *         description: Leases needing renewal
 */
router.get('/expiring', authenticateToken, asyncHandler(renewalController.getLeasesNeedingRenewal));

/**
 * @swagger
 * /api/renewals/bulk:
 *   post:
 *     tags: [Renewals]
 *     summary: Bulk generate renewal offers
 *     description: Auto-generate renewal offers for leases expiring within window.
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               windowDays:
 *                 type: integer
 *                 default: 90
 *               defaultRentIncrease:
 *                 type: number
 *                 default: 0.02
 *               newLeaseDurationMonths:
 *                 type: integer
 *                 default: 12
 *     responses:
 *       200:
 *         description: Bulk renewal offers generated
 */
router.post('/bulk', authenticateToken, validate(renewalSchemas.bulk), asyncHandler(renewalController.generateBulkRenewalOffers));

/**
 * @swagger
 * /api/renewals:
 *   get:
 *     tags: [Renewals]
 *     summary: List renewal offers
 *     description: Returns paginated list of renewal offers.
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: leaseId
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [pending, sent, accepted, declined, expired]
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
 *     responses:
 *       200:
 *         description: List of renewal offers
 */
router.get('/', authenticateToken, asyncHandler(renewalController.getRenewalOffers));

/**
 * @swagger
 * /api/renewals:
 *   post:
 *     tags: [Renewals]
 *     summary: Create a renewal offer
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
 *               - newStartDate
 *               - newEndDate
 *               - newRent
 *             properties:
 *               leaseId:
 *                 type: string
 *                 format: uuid
 *               newStartDate:
 *                 type: string
 *                 format: date
 *               newEndDate:
 *                 type: string
 *                 format: date
 *               newRent:
 *                 type: number
 *               newDeposit:
 *                 type: number
 *     responses:
 *       201:
 *         description: Renewal offer created
 */
router.post('/', authenticateToken, validate(renewalSchemas.create), asyncHandler(renewalController.createRenewalOffer));

/**
 * @swagger
 * /api/renewals/lease/{id}:
 *   get:
 *     tags: [Renewals]
 *     summary: Get renewal offers by lease
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
 *         description: Renewal offers for lease
 */
router.get('/lease/:id', authenticateToken, validate(uuidParam), asyncHandler(renewalController.getRenewalOffersByLease));

/**
 * @swagger
 * /api/renewals/{id}:
 *   get:
 *     tags: [Renewals]
 *     summary: Get renewal offer by ID
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
 *         description: Renewal offer details
 */
router.get('/:id', authenticateToken, validate(uuidParam), asyncHandler(renewalController.getRenewalOfferById));

/**
 * @swagger
 * /api/renewals/{id}:
 *   patch:
 *     tags: [Renewals]
 *     summary: Update a renewal offer
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
 *               newRent:
 *                 type: number
 *               newDeposit:
 *                 type: number
 *     responses:
 *       200:
 *         description: Renewal offer updated
 */
router.patch('/:id', authenticateToken, validate(renewalSchemas.update), asyncHandler(renewalController.updateRenewalOffer));

/**
 * @swagger
 * /api/renewals/{id}/status:
 *   patch:
 *     tags: [Renewals]
 *     summary: Update renewal offer status
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
 *                 enum: [pending, sent, accepted, declined, expired]
 *               tenantResponse:
 *                 type: string
 *     responses:
 *       200:
 *         description: Renewal offer status updated
 */
router.patch('/:id/status', authenticateToken, validate(renewalSchemas.updateStatus), asyncHandler(renewalController.updateRenewalOfferStatus));

/**
 * @swagger
 * /api/renewals/{id}/send:
 *   post:
 *     tags: [Renewals]
 *     summary: Send renewal notification
 *     description: Send SMS and/or email notification to tenant about renewal offer.
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
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               channel:
 *                 type: string
 *                 enum: [sms, email, both]
 *                 default: both
 *     responses:
 *       200:
 *         description: Notification sent
 */
router.post('/:id/send', authenticateToken, validate(renewalSchemas.send), asyncHandler(renewalController.sendRenewalNotification));

module.exports = router;
