const express = require('express');
const { authenticateToken } = require('../auth/jwt.middleware');
const { asyncHandler } = require('../utils/apiResponse');
const validate = require('../middleware/validate');
const { dossierCaseSchemas } = require('../config/validation-schemas');
const controller = require('../controllers/dossier.controller');

const router = express.Router();

router.get('/', authenticateToken, validate(dossierCaseSchemas.list), asyncHandler(controller.listDossierCases));
router.post('/', authenticateToken, validate(dossierCaseSchemas.create), asyncHandler(controller.createDossierCase));
router.get('/:id', authenticateToken, validate(dossierCaseSchemas.detail), asyncHandler(controller.getDossierCaseById));
router.patch('/:id/review', authenticateToken, validate(dossierCaseSchemas.review), asyncHandler(controller.reviewDossierCase));
router.get('/:id/export', authenticateToken, validate(dossierCaseSchemas.export), asyncHandler(controller.exportDossierCase));

module.exports = router;
