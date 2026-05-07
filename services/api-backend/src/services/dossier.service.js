const { and, asc, desc, eq, inArray } = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  communicationLogsTable,
  documentsLeadsTable,
  documentsTable,
  dossierCaseItemsTable,
  dossierCasesTable,
  leadsTable,
  leasesTable,
  paymentsTable,
  renovationTasksTable,
  renovationsTable,
  unitsTable,
  visitsTable,
} = require('../database/schema');

const normalizeDate = (value) => {
  if (!value) {
    return null;
  }
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const toIso = (value) => {
  const date = normalizeDate(value);
  return date ? date.toISOString() : null;
};

const toSortTime = (value) => {
  const date = normalizeDate(value);
  return date ? date.getTime() : Number.POSITIVE_INFINITY;
};

const currency = (value) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return null;
  }
  return new Intl.NumberFormat('fr-CA', {
    style: 'currency',
    currency: 'CAD',
    maximumFractionDigits: 0,
  }).format(Number(value) / 100);
};

const fact = ({ sourceType, sourceId, sourceAt, title, summary, supportingLabel, details = {} }) => ({
  sourceType,
  sourceId,
  sourceAt: toIso(sourceAt),
  title,
  summary,
  supportingLabel,
  details,
});

const buildPaymentFact = (payment) => {
  const effectiveAt = payment.paidDate || payment.dueDate || payment.createdAt;
  return fact({
    sourceType: 'payment',
    sourceId: payment.id,
    sourceAt: effectiveAt,
    title: 'Référence de paiement',
    summary: `${payment.status === 'paid' ? 'Paiement reçu' : 'Paiement à suivre'}${payment.amountCents ? ` ${currency(payment.amountCents)}` : ''}${payment.paidDate ? ` le ${toIso(payment.paidDate)}` : ''}`,
    supportingLabel: payment.reference ? `Référence ${payment.reference}` : 'Historique de paiement',
    details: {
      status: payment.status || null,
      dueDate: toIso(payment.dueDate),
      paidDate: toIso(payment.paidDate),
      amountCents: payment.amountCents ?? null,
    },
  });
};

const buildLeaseFact = (lease) => fact({
  sourceType: 'lease',
  sourceId: lease.id,
  sourceAt: lease.createdAt || lease.startDate,
  title: 'Bail',
  summary: `${lease.status || 'draft'} · ${toIso(lease.startDate) || 'début inconnu'} → ${toIso(lease.endDate) || 'fin inconnue'}`,
  supportingLabel: lease.tenantPhone ? `Téléphone ${lease.tenantPhone}` : 'Contrat de location',
  details: {
    status: lease.status || null,
    startDate: toIso(lease.startDate),
    endDate: toIso(lease.endDate),
    rentCents: lease.rentCents ?? null,
    depositCents: lease.depositCents ?? null,
  },
});

const buildCommunicationFact = (message) => fact({
  sourceType: 'message',
  sourceId: message.id,
  sourceAt: message.createdAt,
  title: 'Message',
  summary: [message.type, message.direction, message.content].filter(Boolean).join(' · '),
  supportingLabel: `${message.type || 'communication'} ${message.direction || ''}`.trim(),
  details: {
    type: message.type || null,
    direction: message.direction || null,
  },
});

const buildDocumentFact = (document) => fact({
  sourceType: 'document',
  sourceId: document.id,
  sourceAt: document.createdAt,
  title: 'Document joint',
  summary: document.name || 'Document lié au dossier',
  supportingLabel: document.type || 'document',
  details: {
    type: document.type || null,
    mimeType: document.mimeType || null,
  },
});

const buildVisitFact = (visit) => fact({
  sourceType: 'visit',
  sourceId: visit.id,
  sourceAt: visit.dateTime,
  title: 'Visite',
  summary: `${visit.status || 'scheduled'}${visit.outcome ? ` · ${visit.outcome}` : ''}`,
  supportingLabel: 'Visite liée au dossier',
  details: {
    status: visit.status || null,
    outcome: visit.outcome || null,
    reasonCode: visit.reasonCode || null,
  },
});

const buildRenovationFact = (renovation, tasks = []) => {
  const taskSummary = tasks.length
    ? `${tasks.length} tâche${tasks.length > 1 ? 's' : ''} liée${tasks.length > 1 ? 's' : ''}`
    : 'Aucune tâche liée';
  const latestTaskTime = tasks
    .map((task) => task.completedAt || task.updatedAt || task.createdAt || null)
    .map(toSortTime)
    .sort((left, right) => left - right)[0];
  return fact({
    sourceType: 'renovation',
    sourceId: renovation.id,
    sourceAt: renovation.updatedAt || renovation.createdAt || latestTaskTime || null,
    title: 'Travaux / remise en état',
    summary: `${renovation.title || 'Travaux'} · ${renovation.status || 'active'} · ${taskSummary}`,
    supportingLabel: renovation.readinessState || 'maintenance',
    details: {
      status: renovation.status || null,
      readinessState: renovation.readinessState || null,
      taskCount: tasks.length,
    },
  });
};

const buildNextSteps = ({ problemCategory, facts, unit, tenant, lease }) => {
  const steps = [];

  if (problemCategory === 'maintenance') {
    steps.push('Planifier un suivi humain avant toute clôture du dossier.');
    steps.push('Demander des photos supplémentaires si l’état visuel demeure incertain.');
    steps.push('Confirmer la résolution avec le locataire et consigner la réponse.');
  } else if (problemCategory === 'payment') {
    steps.push('Vérifier le solde et le bail associé avant tout rappel.');
    steps.push('Préparer un résumé de suivi pour le gestionnaire.');
  } else if (problemCategory === 'visit') {
    steps.push('Vérifier la disponibilité de l’unité et les confirmations liées à la visite.');
    steps.push('Confirmer le prochain créneau avec les personnes concernées.');
  } else {
    steps.push('Préparer un suivi humain avant toute décision.');
    steps.push('Rassembler les pièces justificatives manquantes si nécessaire.');
  }

  if (!facts.some((entry) => entry.sourceType === 'document')) {
    steps.push('Joindre les pièces manquantes avant la revue finale.');
  }

  if (!facts.some((entry) => entry.sourceType === 'message')) {
    steps.push('Relever les messages pertinents du fil de communication.');
  }

  if (!lease?.id) {
    steps.push('Associer un bail actif avant l’export du dossier.');
  }

  if (unit?.label && tenant?.fullName) {
    steps.push(`Préparer la revue finale pour ${tenant.fullName} · ${unit.label}.`);
  }

  return Array.from(new Set(steps));
};

const buildFactualSummary = ({ tenant, unit, lease, problemCategory, facts, incidentWindow }) => {
  const parts = [
    `${tenant?.fullName || 'Le locataire'} est lié à l’unité ${unit?.label || 'non précisée'}.`,
    lease?.status ? `Le bail associé est ${lease.status}.` : 'Aucun bail actif n’a été fourni.',
    problemCategory ? `Catégorie du dossier : ${problemCategory}.` : null,
  ].filter(Boolean);

  if (incidentWindow?.startAt || incidentWindow?.endAt) {
    const start = incidentWindow.startAt ? toIso(incidentWindow.startAt) : 'début inconnu';
    const end = incidentWindow.endAt ? toIso(incidentWindow.endAt) : 'fin inconnue';
    parts.push(`Fenêtre d’incident : ${start} à ${end}.`);
  }

  if (facts.length) {
    parts.push(`Le dossier regroupe ${facts.length} élément${facts.length > 1 ? 's' : ''} de faits et de pièces appuyées par des sources.`);
  }

  return parts.join(' ');
};

function buildDossierDraft({
  problemCategory,
  tenant,
  unit,
  lease,
  payments = [],
  communications = [],
  documents = [],
  visits = [],
  renovations = [],
  renovationTasks = [],
  incidentWindow = null,
}) {
  const facts = [
    ...(lease ? [buildLeaseFact(lease)] : []),
    ...payments.map(buildPaymentFact),
    ...communications.map(buildCommunicationFact),
    ...documents.map(buildDocumentFact),
    ...visits.map(buildVisitFact),
    ...renovations.map((renovation) => buildRenovationFact(
      renovation,
      renovationTasks.filter((task) => task.renovationRecordId === renovation.id),
    )),
  ].sort((left, right) => toSortTime(left.sourceAt) - toSortTime(right.sourceAt));

  const nextSteps = buildNextSteps({ problemCategory, facts, unit, tenant, lease });
  const factualSummary = buildFactualSummary({ tenant, unit, lease, problemCategory, facts, incidentWindow });

  return {
    problemCategory,
    tenant: tenant || null,
    unit: unit || null,
    lease: lease || null,
    incidentWindow,
    status: 'draft',
    factualSummary,
    facts,
    nextSteps,
    exportSections: {
      facts,
      evidence: facts,
      nextSteps,
    },
  };
}

const loadDossierInputs = async ({ companyId, leadId, unitId }) => {
  const [tenant, unit] = await Promise.all([
    leadId
      ? db.select().from(leadsTable).where(eq(leadsTable.id, leadId)).limit(1).then((rows) => rows[0] || null)
      : Promise.resolve(null),
    unitId
      ? db.select().from(unitsTable).where(eq(unitsTable.id, unitId)).limit(1).then((rows) => rows[0] || null)
      : Promise.resolve(null),
  ]);

  if (leadId && !tenant) {
    const error = new Error('Tenant not found');
    error.code = 'DOSSIER_TENANT_NOT_FOUND';
    error.statusCode = 404;
    throw error;
  }

  if (unitId && !unit) {
    const error = new Error('Unit not found');
    error.code = 'DOSSIER_UNIT_NOT_FOUND';
    error.statusCode = 404;
    throw error;
  }

  const buildingId = unit?.buildingId || null;

  const visitConditions = [];
  if (unit?.id) {
    visitConditions.push(eq(visitsTable.unitId, unit.id));
  }
  if (tenant?.id) {
    visitConditions.push(eq(visitsTable.leadId, tenant.id));
  }

  const [lease, communications, documentsFromLeads, directDocuments, unitDocuments, buildingDocuments, visits, renovations] = await Promise.all([
    unit?.id
      ? db.select().from(leasesTable).where(eq(leasesTable.unitId, unit.id)).orderBy(desc(leasesTable.createdAt)).limit(1).then((rows) => rows[0] || null)
      : Promise.resolve(null),
    tenant?.id
      ? db.select().from(communicationLogsTable).where(eq(communicationLogsTable.leadId, tenant.id)).orderBy(asc(communicationLogsTable.createdAt))
      : Promise.resolve([]),
    tenant?.id
      ? db.select({ document: documentsTable })
        .from(documentsLeadsTable)
        .innerJoin(documentsTable, eq(documentsTable.id, documentsLeadsTable.documentId))
        .where(eq(documentsLeadsTable.leadId, tenant.id))
        .then((rows) => rows.map((row) => row.document))
      : Promise.resolve([]),
    tenant?.id
      ? db.select().from(documentsTable).where(and(eq(documentsTable.referenceType, 'lead'), eq(documentsTable.referenceId, tenant.id)))
      : Promise.resolve([]),
    unit?.id
      ? db.select().from(documentsTable).where(and(eq(documentsTable.referenceType, 'unit'), eq(documentsTable.referenceId, unit.id)))
      : Promise.resolve([]),
    buildingId
      ? db.select().from(documentsTable).where(and(eq(documentsTable.referenceType, 'building'), eq(documentsTable.referenceId, buildingId)))
      : Promise.resolve([]),
    visitConditions.length
      ? db.select().from(visitsTable).where(and(...visitConditions)).orderBy(asc(visitsTable.dateTime))
      : Promise.resolve([]),
    unit?.id
      ? db.select().from(renovationsTable).where(eq(renovationsTable.unitId, unit.id)).orderBy(desc(renovationsTable.updatedAt))
      : Promise.resolve([]),
  ]);

  const renovationIds = renovations.map((renovation) => renovation.id);
  const [paymentRows, taskRows] = await Promise.all([
    lease?.id
      ? db.select().from(paymentsTable).where(eq(paymentsTable.leaseId, lease.id)).orderBy(asc(paymentsTable.dueDate))
      : Promise.resolve([]),
    renovationIds.length
      ? db.select().from(renovationTasksTable).where(inArray(renovationTasksTable.renovationRecordId, renovationIds)).orderBy(asc(renovationTasksTable.createdAt))
      : Promise.resolve([]),
  ]);

  return {
    companyId,
    tenant,
    unit,
    lease,
    payments: paymentRows,
    communications: communications,
    documents: [
      ...documentsFromLeads,
      ...directDocuments,
      ...unitDocuments,
      ...buildingDocuments,
    ],
    visits,
    renovations,
    renovationTasks: taskRows,
  };
};

const serializeDossierCase = (dossierCase, items = []) => ({
  ...dossierCase,
  incidentWindowStart: toIso(dossierCase.incidentWindowStart),
  incidentWindowEnd: toIso(dossierCase.incidentWindowEnd),
  reviewedAt: toIso(dossierCase.reviewedAt),
  exportedAt: toIso(dossierCase.exportedAt),
  createdAt: toIso(dossierCase.createdAt),
  updatedAt: toIso(dossierCase.updatedAt),
  items: items.map((item) => ({
    ...item,
    sourceAt: toIso(item.sourceAt),
    createdAt: toIso(item.createdAt),
    updatedAt: toIso(item.updatedAt),
  })),
  exportSections: {
    facts: items.map((item) => ({
      sourceType: item.sourceType,
      sourceRecordId: item.sourceRecordId,
      sourceAt: toIso(item.sourceAt),
      title: item.title,
      summary: item.summary,
      supportingLabel: item.supportingLabel,
      details: item.details,
    })),
    evidence: items.map((item) => ({
      sourceType: item.sourceType,
      sourceRecordId: item.sourceRecordId,
      sourceAt: toIso(item.sourceAt),
      title: item.title,
      summary: item.summary,
      supportingLabel: item.supportingLabel,
      details: item.details,
    })),
    nextSteps: Array.isArray(dossierCase.nextSteps) ? dossierCase.nextSteps : [],
  },
});

const getDossierCaseById = async ({ companyId, dossierCaseId }) => {
  const [row] = await db.select()
    .from(dossierCasesTable)
    .where(and(eq(dossierCasesTable.companyId, companyId), eq(dossierCasesTable.id, dossierCaseId)))
    .limit(1);

  if (!row) {
    const error = new Error('Dossier case not found');
    error.code = 'DOSSIER_CASE_NOT_FOUND';
    error.statusCode = 404;
    throw error;
  }

  const items = await db.select()
    .from(dossierCaseItemsTable)
    .where(and(eq(dossierCaseItemsTable.companyId, companyId), eq(dossierCaseItemsTable.dossierCaseId, dossierCaseId)))
    .orderBy(asc(dossierCaseItemsTable.sortOrder), asc(dossierCaseItemsTable.createdAt));

  return serializeDossierCase(row, items);
};

const createDossierCase = async ({
  companyId,
  leadId,
  unitId,
  problemCategory,
  incidentWindowStart,
  incidentWindowEnd,
  createdByUserId,
}) => {
  if (!companyId) {
    const error = new Error('companyId is required');
    error.code = 'DOSSIER_COMPANY_REQUIRED';
    error.statusCode = 400;
    throw error;
  }

  if (!leadId && !unitId) {
    const error = new Error('leadId or unitId is required');
    error.code = 'DOSSIER_SELECTION_REQUIRED';
    error.statusCode = 400;
    throw error;
  }

  if (!problemCategory) {
    const error = new Error('problemCategory is required');
    error.code = 'DOSSIER_CATEGORY_REQUIRED';
    error.statusCode = 400;
    throw error;
  }

  const inputs = await loadDossierInputs({ companyId, leadId, unitId });
  const draft = buildDossierDraft({
    problemCategory,
    tenant: inputs.tenant,
    unit: inputs.unit,
    lease: inputs.lease,
    payments: inputs.payments,
    communications: inputs.communications,
    documents: inputs.documents,
    visits: inputs.visits,
    renovations: inputs.renovations,
    renovationTasks: inputs.renovationTasks,
    incidentWindow: {
      startAt: incidentWindowStart || null,
      endAt: incidentWindowEnd || null,
    },
  });

  const [dossierCase] = await db.insert(dossierCasesTable).values({
    companyId,
    leadId: leadId || null,
    unitId: unitId || null,
    buildingId: inputs.unit?.buildingId || null,
    problemCategory,
    incidentWindowStart: normalizeDate(incidentWindowStart),
    incidentWindowEnd: normalizeDate(incidentWindowEnd),
    status: 'draft',
    factualSummary: draft.factualSummary,
    nextSteps: draft.nextSteps,
    createdByUserId: createdByUserId || null,
    updatedAt: new Date(),
  }).returning();

  if (draft.facts.length) {
    await db.insert(dossierCaseItemsTable).values(draft.facts.map((item, index) => ({
      companyId,
      dossierCaseId: dossierCase.id,
      sourceType: item.sourceType,
      sourceRecordId: String(item.sourceId),
      sourceAt: item.sourceAt ? new Date(item.sourceAt) : null,
      sortOrder: index,
      title: item.title,
      summary: item.summary,
      supportingLabel: item.supportingLabel || null,
      details: item.details || {},
      updatedAt: new Date(),
    })));
  }

  return getDossierCaseById({ companyId, dossierCaseId: dossierCase.id });
};

const listDossierCases = async ({ companyId, status = null, limit = 20 }) => {
  const conditions = [eq(dossierCasesTable.companyId, companyId), eq(dossierCasesTable.isActive, true)];
  if (status) {
    conditions.push(eq(dossierCasesTable.status, status));
  }

  const rows = await db.select()
    .from(dossierCasesTable)
    .where(and(...conditions))
    .orderBy(desc(dossierCasesTable.updatedAt))
    .limit(limit);

  return rows.map((row) => serializeDossierCase(row, []));
};

const reviewDossierCase = async ({ companyId, dossierCaseId, status, reviewNotes, reviewedByUserId }) => {
  const [existing] = await db.select()
    .from(dossierCasesTable)
    .where(and(eq(dossierCasesTable.companyId, companyId), eq(dossierCasesTable.id, dossierCaseId)))
    .limit(1);

  if (!existing) {
    const error = new Error('Dossier case not found');
    error.code = 'DOSSIER_CASE_NOT_FOUND';
    error.statusCode = 404;
    throw error;
  }

  const [updated] = await db.update(dossierCasesTable)
    .set({
      status: status || 'in_review',
      reviewNotes: reviewNotes ?? existing.reviewNotes,
      reviewedByUserId: reviewedByUserId || existing.reviewedByUserId,
      reviewedAt: new Date(),
      updatedAt: new Date(),
    })
    .where(and(eq(dossierCasesTable.companyId, companyId), eq(dossierCasesTable.id, dossierCaseId)))
    .returning();

  return getDossierCaseById({ companyId, dossierCaseId: updated.id });
};

const exportDossierCase = async ({ companyId, dossierCaseId, exportedByUserId }) => {
  const [existing] = await db.select()
    .from(dossierCasesTable)
    .where(and(eq(dossierCasesTable.companyId, companyId), eq(dossierCasesTable.id, dossierCaseId)))
    .limit(1);

  if (!existing) {
    const error = new Error('Dossier case not found');
    error.code = 'DOSSIER_CASE_NOT_FOUND';
    error.statusCode = 404;
    throw error;
  }

  const [updated] = await db.update(dossierCasesTable)
    .set({
      status: 'exported',
      exportedByUserId: exportedByUserId || existing.exportedByUserId,
      exportedAt: new Date(),
      updatedAt: new Date(),
    })
    .where(and(eq(dossierCasesTable.companyId, companyId), eq(dossierCasesTable.id, dossierCaseId)))
    .returning();

  return getDossierCaseById({ companyId, dossierCaseId: updated.id });
};

module.exports = {
  buildDossierDraft,
  createDossierCase,
  getDossierCaseById,
  listDossierCases,
  reviewDossierCase,
  exportDossierCase,
  serializeDossierCase,
};
