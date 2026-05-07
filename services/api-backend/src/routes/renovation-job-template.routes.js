const express = require('express');
const Joi = require('joi');
const { authenticateToken } = require('../auth/jwt.middleware');
const validate = require('../middleware/validate');
const { asyncHandler } = require('../utils/apiResponse');
const renovationJobTemplateController = require('../controllers/renovation-job-template.controller');

const router = express.Router();

const companyParamSchema = { params: Joi.object({ companyId: Joi.string().uuid().required() }) };
const companyTemplateParamSchema = { params: Joi.object({ companyId: Joi.string().uuid().required(), id: Joi.string().uuid().required() }) };

router.use(authenticateToken);
router.use(validate(companyParamSchema));

router.get('/', asyncHandler(renovationJobTemplateController.listRenovationJobTemplates));
router.post('/', asyncHandler(renovationJobTemplateController.createRenovationJobTemplate));
router.patch('/:id', validate(companyTemplateParamSchema), asyncHandler(renovationJobTemplateController.updateRenovationJobTemplate));
router.delete('/:id', validate(companyTemplateParamSchema), asyncHandler(renovationJobTemplateController.deleteRenovationJobTemplate));

module.exports = router;
