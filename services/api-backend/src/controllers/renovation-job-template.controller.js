const { eq, and, desc, sql } = require('drizzle-orm');
const { db } = require('../database/connection');
const { renovationJobTemplatesTable } = require('../database/schema');
const {
  renovationJobTemplateSchema,
  updateRenovationJobTemplateSchema,
  withSuggestedMissingItems,
} = require('../models/renovation-job-template');
const { child } = require('../utils/logger');

const log = child({ controller: 'renovation-job-template' });

const success = (res, data, message, metadata) => {
  const payload = { success: true, data, message };
  if (metadata) { payload.metadata = metadata; }
  return res.json(payload);
};

const error = (res, status, code, message) => res.status(status).json({
  success: false,
  error: { code, message },
});

const parsePagination = (query) => {
  const page = Math.max(1, parseInt(query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(query.limit, 10) || 20));
  return { page, limit, offset: (page - 1) * limit };
};

const loadTemplate = async ({ companyId, id }) => {
  const [template] = await db.select()
    .from(renovationJobTemplatesTable)
    .where(and(eq(renovationJobTemplatesTable.companyId, companyId), eq(renovationJobTemplatesTable.id, id)))
    .limit(1);
  return template || null;
};

const buildTemplateValues = (companyId, value, existing = null) => {
  const merged = {
    companyId,
    name: value.name ?? existing?.name,
    description: value.description !== undefined ? value.description : existing?.description ?? null,
    isFavorite: value.isFavorite !== undefined ? value.isFavorite : existing?.isFavorite ?? false,
    materials: value.materials !== undefined ? value.materials : existing?.materials ?? [],
    notes: value.notes !== undefined ? value.notes : existing?.notes ?? null,
    manualProductLinks: value.manualProductLinks !== undefined ? value.manualProductLinks : existing?.manualProductLinks ?? [],
    sourceTags: value.sourceTags !== undefined ? value.sourceTags : existing?.sourceTags ?? [],
    updatedAt: new Date(),
  };

  return withSuggestedMissingItems(merged);
};

exports.listRenovationJobTemplates = async (req, res) => {
  try {
    const { page, limit, offset } = parsePagination(req.query);
    const conditions = [eq(renovationJobTemplatesTable.companyId, req.params.companyId), eq(renovationJobTemplatesTable.isActive, true)];
    if (req.query.favorite === 'true' || req.query.favorite === '1') {
      conditions.push(eq(renovationJobTemplatesTable.isFavorite, true));
    }
    const whereClause = and(...conditions);

    const [{ count: total }] = await db.select({ count: sql`count(*)::int` }).from(renovationJobTemplatesTable).where(whereClause);
    const templates = await db.select()
      .from(renovationJobTemplatesTable)
      .where(whereClause)
      .orderBy(desc(renovationJobTemplatesTable.isFavorite), desc(renovationJobTemplatesTable.updatedAt))
      .limit(limit)
      .offset(offset);

    return success(res, templates, 'Modèles récupérés avec succès', {
      total, page, limit, totalPages: Math.ceil((total || 0) / limit) || 0, hasMore: page * limit < total,
    });
  } catch (err) {
    log.error('Error fetching renovation job templates', { error: err.message });
    return error(res, 500, 'RENOVATION_JOB_TEMPLATES_FETCH_FAILED', 'Erreur interne du serveur');
  }
};

exports.createRenovationJobTemplate = async (req, res) => {
  try {
    const { error: validationError, value } = renovationJobTemplateSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const templateValues = buildTemplateValues(req.params.companyId, value);
    const [template] = await db.insert(renovationJobTemplatesTable).values({
      companyId: req.params.companyId,
      name: templateValues.name,
      description: templateValues.description,
      isFavorite: templateValues.isFavorite,
      materials: templateValues.materials,
      notes: templateValues.notes,
      manualProductLinks: templateValues.manualProductLinks,
      sourceTags: templateValues.sourceTags,
      suggestedMissingItems: templateValues.suggestedMissingItems,
    }).returning();

    return res.status(201).json({ success: true, data: template, message: 'Modèle enregistré avec succès' });
  } catch (err) {
    log.error('Error creating renovation job template', { error: err.message });
    return error(res, 500, 'RENOVATION_JOB_TEMPLATE_CREATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.updateRenovationJobTemplate = async (req, res) => {
  try {
    const { error: validationError, value } = updateRenovationJobTemplateSchema.validate(req.body);
    if (validationError) {
      return error(res, 400, 'VALIDATION_ERROR', validationError.details[0].message);
    }

    const existing = await loadTemplate({ companyId: req.params.companyId, id: req.params.id });
    if (!existing) {
      return error(res, 404, 'RENOVATION_JOB_TEMPLATE_NOT_FOUND', 'Modèle introuvable');
    }

    const templateValues = buildTemplateValues(req.params.companyId, value, existing);
    const [updated] = await db.update(renovationJobTemplatesTable).set({
      name: templateValues.name,
      description: templateValues.description,
      isFavorite: templateValues.isFavorite,
      materials: templateValues.materials,
      notes: templateValues.notes,
      manualProductLinks: templateValues.manualProductLinks,
      sourceTags: templateValues.sourceTags,
      suggestedMissingItems: templateValues.suggestedMissingItems,
      updatedAt: new Date(),
    }).where(and(eq(renovationJobTemplatesTable.companyId, req.params.companyId), eq(renovationJobTemplatesTable.id, existing.id))).returning();

    return success(res, updated, 'Modèle mis à jour avec succès');
  } catch (err) {
    log.error('Error updating renovation job template', { error: err.message });
    return error(res, 500, 'RENOVATION_JOB_TEMPLATE_UPDATE_FAILED', 'Erreur interne du serveur');
  }
};

exports.deleteRenovationJobTemplate = async (req, res) => {
  try {
    const existing = await loadTemplate({ companyId: req.params.companyId, id: req.params.id });
    if (!existing) {
      return error(res, 404, 'RENOVATION_JOB_TEMPLATE_NOT_FOUND', 'Modèle introuvable');
    }

    await db.update(renovationJobTemplatesTable).set({ isActive: false, updatedAt: new Date() }).where(and(eq(renovationJobTemplatesTable.companyId, req.params.companyId), eq(renovationJobTemplatesTable.id, existing.id)));
    return success(res, null, 'Modèle archivé avec succès');
  } catch (err) {
    log.error('Error deleting renovation job template', { error: err.message });
    return error(res, 500, 'RENOVATION_JOB_TEMPLATE_DELETE_FAILED', 'Erreur interne du serveur');
  }
};
