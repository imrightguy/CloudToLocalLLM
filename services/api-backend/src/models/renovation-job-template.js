const Joi = require('joi');

const jobTemplateMaterialSchema = Joi.object({
  name: Joi.string().trim().min(1).max(255).required(),
  quantity: Joi.number().integer().min(1).default(1),
  unit: Joi.string().trim().max(64).optional().allow(null, ''),
  note: Joi.string().trim().max(500).optional().allow(null, ''),
}).unknown(false);

const jobTemplateProductLinkSchema = Joi.object({
  label: Joi.string().trim().min(1).max(255).required(),
  url: Joi.string().uri({ scheme: ['http', 'https'] }).required(),
  note: Joi.string().trim().max(500).optional().allow(null, ''),
}).unknown(false);

const renovationJobTemplateSchema = Joi.object({
  name: Joi.string().trim().min(1).max(255).required(),
  description: Joi.string().trim().max(2000).optional().allow(null, ''),
  isFavorite: Joi.boolean().default(false),
  materials: Joi.array().items(Joi.alternatives().try(
    Joi.string().trim().min(1).max(255),
    jobTemplateMaterialSchema,
  )).default([]),
  notes: Joi.string().trim().max(5000).optional().allow(null, ''),
  manualProductLinks: Joi.array().items(jobTemplateProductLinkSchema).default([]),
  sourceTags: Joi.array().items(Joi.string().trim().min(1).max(120)).default([]),
});

const updateRenovationJobTemplateSchema = Joi.object({
  name: Joi.string().trim().min(1).max(255),
  description: Joi.string().trim().max(2000).optional().allow(null, ''),
  isFavorite: Joi.boolean(),
  materials: Joi.array().items(Joi.alternatives().try(
    Joi.string().trim().min(1).max(255),
    jobTemplateMaterialSchema,
  )),
  notes: Joi.string().trim().max(5000).optional().allow(null, ''),
  manualProductLinks: Joi.array().items(jobTemplateProductLinkSchema),
  sourceTags: Joi.array().items(Joi.string().trim().min(1).max(120)),
}).min(1);

const TEMPLATE_SUGGESTION_RULES = [
  {
    tokens: ['paint', 'peinture', 'primer', 'apprêt'],
    items: ['Painter\'s tape', 'Drop cloth', 'Sanding sponges', 'Paint tray liners'],
  },
  {
    tokens: ['drywall', 'gypsum', 'plaster', 'gypse', 'cloison'],
    items: ['Joint compound', 'Drywall tape', 'Sanding screen', 'Drywall screws'],
  },
  {
    tokens: ['bathroom', 'bath', 'vanity', 'toilet', 'sink', 'salle de bain', 'lavabo'],
    items: ['Silicone caulk', 'Anchors', 'Plumber\'s tape', 'Shims'],
  },
  {
    tokens: ['kitchen', 'cabinet', 'cabinets', 'cuisine'],
    items: ['Cabinet screws', 'Shims', 'Wood filler', 'Level'],
  },
  {
    tokens: ['floor', 'tile', 'tiling', 'carrelage', 'tuile'],
    items: ['Tile spacers', 'Thinset', 'Grout', 'Tile leveling clips'],
  },
  {
    tokens: ['light', 'lighting', 'fixture', 'luminaire', 'lumiere'],
    items: ['Wire nuts', 'Electrical tape', 'Junction box screws', 'Bulbs'],
  },
  {
    tokens: ['door', 'trim', 'baseboard', 'moulding', 'moulure'],
    items: ['Finish nails', 'Wood filler', 'Caulk', 'Sandpaper'],
  },
  {
    tokens: ['plumbing', 'plumb', 'pipe', 'tuyau', 'robinet'],
    items: ['Pipe thread tape', 'Pipe straps', 'Hose clamps', 'Silicone sealant'],
  },
];

const COMMON_SMALL_ITEMS = [
  'Anchors',
  'Caulk',
  'Painter\'s tape',
  'Utility blades',
  'Screws',
];

const normalizeText = (value) => String(value || '')
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '')
  .toLowerCase();

const flattenTemplateText = ({ name, description, notes, materials }) => normalizeText([
  name,
  description,
  notes,
  ...(Array.isArray(materials) ? materials.map((material) => {
    if (typeof material === 'string') { return material; }
    if (material && typeof material === 'object') {
      return [material.name, material.unit, material.note].filter(Boolean).join(' ');
    }
    return '';
  }) : []),
].filter(Boolean).join(' '));

const deriveSuggestedMissingItems = ({ name, description, notes, materials = [] }) => {
  const context = flattenTemplateText({ name, description, notes, materials });
  const materialNames = new Set((Array.isArray(materials) ? materials : [])
    .flatMap((material) => {
      if (typeof material === 'string') { return [normalizeText(material)]; }
      if (material && typeof material === 'object') {
        return [normalizeText(material.name), normalizeText(material.unit), normalizeText(material.note)];
      }
      return [];
    })
    .filter(Boolean));

  const suggestions = [];
  const addSuggestion = (item) => {
    const normalizedItem = normalizeText(item);
    if (!normalizedItem) { return; }
    if (materialNames.has(normalizedItem)) { return; }
    if (context.includes(normalizedItem)) { return; }
    if (suggestions.some((existing) => normalizeText(existing) === normalizedItem)) { return; }
    suggestions.push(item);
  };

  TEMPLATE_SUGGESTION_RULES.forEach((rule) => {
    if (rule.tokens.some((token) => context.includes(token))) {
      rule.items.forEach(addSuggestion);
    }
  });

  COMMON_SMALL_ITEMS.forEach(addSuggestion);

  return suggestions.slice(0, 8);
};

const withSuggestedMissingItems = (template) => ({
  ...template,
  suggestedMissingItems: deriveSuggestedMissingItems(template),
});

module.exports = {
  jobTemplateMaterialSchema,
  jobTemplateProductLinkSchema,
  renovationJobTemplateSchema,
  updateRenovationJobTemplateSchema,
  deriveSuggestedMissingItems,
  withSuggestedMissingItems,
};
