// ─── Message Templates Routes ───
// Authenticated read/update for the customizable automatic-message templates.
// Mounted at /api/message-templates.

const express = require('express');

const router = express.Router();
const messageTemplatesController = require('../controllers/message-templates.controller');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { messageTemplateSchemas } = require('../config/validation-schemas');

router.get(
  '/',
  authenticateToken,
  asyncHandler(messageTemplatesController.list),
);

router.put(
  '/:eventType',
  authenticateToken,
  validate(messageTemplateSchemas.update),
  asyncHandler(messageTemplatesController.update),
);

module.exports = router;
