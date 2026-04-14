const express = require('express');
const { authenticateToken, authorizeRole } = require('../auth/jwt.middleware');
const { seedDemo, clearDemo } = require('../controllers/admin.controller');

const router = express.Router();

router.post('/seed', authenticateToken, authorizeRole(['admin']), seedDemo);
router.delete('/seed', authenticateToken, authorizeRole(['admin']), clearDemo);

module.exports = router;
