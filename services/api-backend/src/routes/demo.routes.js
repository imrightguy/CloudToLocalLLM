const express = require('express');
const { demoLogin, getDemoStatus } = require('../controllers/demo.controller');

const router = express.Router();

router.post('/login', demoLogin);

router.get('/status', getDemoStatus);

module.exports = router;
