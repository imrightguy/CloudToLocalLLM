const express = require('express');
const router = express.Router();
const { getStreetView } = require('../controllers/building-streetview.controller');
const { authenticateToken } = require('../auth/jwt.middleware');

// GET /api/buildings/:id/streetview — proxy Google Street View (public, no auth required)
router.get('/:id/streetview', getStreetView);

module.exports = router;
