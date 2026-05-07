const dossierService = require('../services/dossier.service');
const { child } = require('../utils/logger');

const log = child({ controller: 'dossier' });

const success = (res, data, message, metadata) => {
  const payload = { success: true, data, message };
  if (metadata) {
    payload.metadata = metadata;
  }
  return res.json(payload);
};

const error = (res, status, code, message) => res.status(status).json({
  success: false,
  error: { code, message },
});

const toInt = (value, fallback) => {
  const parsed = parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
};

const handleServiceError = (res, err, fallbackCode) => {
  const status = err.statusCode || 500;
  const code = err.code || fallbackCode;
  const message = err.message || 'Internal server error';
  if (status === 500) {
    log.error('Dossier controller error', { error: message, code: code || fallbackCode });
  }
  return error(res, status, code, message);
};

exports.listDossierCases = async (req, res) => {
  try {
    const rows = await dossierService.listDossierCases({
      companyId: req.params.companyId,
      status: req.query.status || null,
      limit: Math.min(100, Math.max(1, toInt(req.query.limit, 20))),
    });
    return success(res, rows, 'Dossier cases retrieved successfully', { count: rows.length });
  } catch (err) {
    return handleServiceError(res, err, 'DOSSIER_CASE_LIST_FAILED');
  }
};

exports.createDossierCase = async (req, res) => {
  try {
    const created = await dossierService.createDossierCase({
      companyId: req.params.companyId,
      leadId: req.body.leadId,
      unitId: req.body.unitId,
      problemCategory: req.body.problemCategory,
      incidentWindowStart: req.body.incidentWindowStart,
      incidentWindowEnd: req.body.incidentWindowEnd,
      createdByUserId: req.user?.id || null,
    });

    return res.status(201).json({
      success: true,
      data: created,
      message: 'Dossier case created successfully',
    });
  } catch (err) {
    return handleServiceError(res, err, 'DOSSIER_CASE_CREATE_FAILED');
  }
};

exports.getDossierCaseById = async (req, res) => {
  try {
    const row = await dossierService.getDossierCaseById({
      companyId: req.params.companyId,
      dossierCaseId: req.params.id,
    });
    return success(res, row, 'Dossier case retrieved successfully');
  } catch (err) {
    return handleServiceError(res, err, 'DOSSIER_CASE_FETCH_FAILED');
  }
};

exports.reviewDossierCase = async (req, res) => {
  try {
    const row = await dossierService.reviewDossierCase({
      companyId: req.params.companyId,
      dossierCaseId: req.params.id,
      status: req.body.status,
      reviewNotes: req.body.reviewNotes,
      reviewedByUserId: req.user?.id || null,
    });
    return success(res, row, 'Dossier case reviewed successfully');
  } catch (err) {
    return handleServiceError(res, err, 'DOSSIER_CASE_REVIEW_FAILED');
  }
};

exports.exportDossierCase = async (req, res) => {
  try {
    const row = await dossierService.exportDossierCase({
      companyId: req.params.companyId,
      dossierCaseId: req.params.id,
      exportedByUserId: req.user?.id || null,
    });
    return success(res, row, 'Dossier case exported successfully');
  } catch (err) {
    return handleServiceError(res, err, 'DOSSIER_CASE_EXPORT_FAILED');
  }
};
