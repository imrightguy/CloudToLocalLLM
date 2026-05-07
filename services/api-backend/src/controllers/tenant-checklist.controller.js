const tenantChecklistService = require('../services/tenant-checklist.service');
const { child } = require('../utils/logger');

const log = child({ controller: 'tenant-checklist' });

const success = (res, data, message) => res.json({
  success: true,
  data,
  message,
});

const handleError = (res, err, fallbackCode) => {
  const status = err.statusCode || 500;
  const code = err.code || fallbackCode;
  const message = err.message || 'Erreur interne du serveur';

  if (status === 500) {
    log.error('Tenant checklist controller error', { code, error: message });
  }

  return res.status(status).json({
    success: false,
    error: { code, message },
  });
};

exports.startChecklistSession = async (req, res) => {
  try {
    const result = await tenantChecklistService.startChecklistSession({
      unitId: req.body.unitId,
      leaseId: req.body.leaseId || null,
      checklistType: req.body.checklistType,
      tenantName: req.body.tenantName || null,
      tenantPhone: req.body.tenantPhone || null,
      metadata: req.body.metadata || {},
      createdByUserId: req.user?.id || null,
    });

    return res.status(201).json({
      success: true,
      data: result,
      message: 'Session de checklist créée avec succès',
    });
  } catch (err) {
    return handleError(res, err, 'TENANT_CHECKLIST_START_FAILED');
  }
};

exports.resumeChecklistSession = async (req, res) => {
  try {
    const result = await tenantChecklistService.resumeChecklistSession({
      sessionId: req.params.id,
      resumedByUserId: req.body.resumedByUserId || req.user?.id || null,
      metadata: req.body.metadata || {},
    });

    return success(res, result, 'Session de checklist reprise avec succès');
  } catch (err) {
    return handleError(res, err, 'TENANT_CHECKLIST_RESUME_FAILED');
  }
};

exports.pauseChecklistSession = async (req, res) => {
  try {
    const result = await tenantChecklistService.pauseChecklistSession({
      sessionId: req.params.id,
      pausedByUserId: req.body.pausedByUserId || req.user?.id || null,
      reason: req.body.reason || null,
      metadata: req.body.metadata || {},
    });

    return success(res, result, 'Session de checklist mise en pause avec succès');
  } catch (err) {
    return handleError(res, err, 'TENANT_CHECKLIST_PAUSE_FAILED');
  }
};

exports.submitChecklistSession = async (req, res) => {
  try {
    const result = await tenantChecklistService.submitChecklistSession({
      sessionId: req.params.id,
      submittedByUserId: req.body.submittedByUserId || req.user?.id || null,
      confirmationNote: req.body.confirmationNote || null,
      forceComplete: req.body.forceComplete || false,
      stepUpdates: req.body.stepUpdates || [],
      attachments: req.body.attachments || [],
      signatures: req.body.signatures || [],
      metadata: req.body.metadata || {},
    });

    return success(res, result, 'Session de checklist soumise avec succès');
  } catch (err) {
    return handleError(res, err, 'TENANT_CHECKLIST_SUBMIT_FAILED');
  }
};

exports.getChecklistSessionSummary = async (req, res) => {
  try {
    const result = await tenantChecklistService.getChecklistSessionSummary({
      sessionId: req.params.id,
    });

    return success(res, result, 'Résumé de checklist récupéré avec succès');
  } catch (err) {
    return handleError(res, err, 'TENANT_CHECKLIST_SUMMARY_FAILED');
  }
};

exports.getManagerChecklistSessionSummary = async (req, res) => {
  try {
    const result = await tenantChecklistService.getChecklistSessionSummary({
      sessionId: req.params.id,
    });

    return success(res, result, 'Résumé gestionnaire de checklist récupéré avec succès');
  } catch (err) {
    return handleError(res, err, 'TENANT_CHECKLIST_MANAGER_SUMMARY_FAILED');
  }
};
