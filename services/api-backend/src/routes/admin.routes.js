const express = require('express');
const { authenticateToken, authorizeRole } = require('../auth/jwt.middleware');
const { seedDemo, clearDemo } = require('../controllers/admin.controller');

const router = express.Router();

/**
 * @swagger
 * /api/admin/seed:
 *   post:
 *     tags: [Admin]
 *     summary: Seed demo data
 *     description: Populate the database with demo data (buildings, units, leads, visits, etc.). Admin only.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Demo data seeded successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       403:
 *         description: Forbidden — admin role required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/seed', authenticateToken, authorizeRole(['admin']), seedDemo);

/**
 * @swagger
 * /api/admin/seed:
 *   delete:
 *     tags: [Admin]
 *     summary: Clear demo data
 *     description: Remove all demo data from the database. Admin only.
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Demo data cleared successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       403:
 *         description: Forbidden — admin role required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.delete('/seed', authenticateToken, authorizeRole(['admin']), clearDemo);

module.exports = router;
