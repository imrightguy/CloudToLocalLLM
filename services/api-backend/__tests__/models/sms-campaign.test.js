const {
  templateSchema,
  updateTemplateSchema,
  campaignSchema,
  updateCampaignSchema,
  activateCampaignSchema,
  VALID_TEMPLATE_CATEGORIES,
  VALID_AUDIENCES,
  VALID_SCHEDULE_TYPES,
  VALID_CAMPAIGN_STATUSES,
} = require('../../src/models/sms-campaign');

describe('templateSchema', () => {
  const validTemplate = {
    name: 'Rappel de visite',
    body: 'Bonjour {{name}}, votre visite est prévue le {{date}}.',
    category: 'visit_reminder',
  };

  it('validates a minimal valid template', () => {
    const { error, value } = templateSchema.validate(validTemplate);
    expect(error).toBeUndefined();
    expect(value.name).toBe('Rappel de visite');
    expect(value.language).toBe('fr');
    expect(value.variables).toEqual([]);
  });

  it('validates a full template with all fields', () => {
    const full = {
      ...validTemplate,
      language: 'en',
      description: 'Visit reminder template',
      variables: ['name', 'date', 'time'],
    };
    const { error, value } = templateSchema.validate(full);
    expect(error).toBeUndefined();
    expect(value.language).toBe('en');
    expect(value.description).toBe('Visit reminder template');
    expect(value.variables).toEqual(['name', 'date', 'time']);
  });

  it('defaults language to fr', () => {
    const { value } = templateSchema.validate(validTemplate);
    expect(value.language).toBe('fr');
  });

  it('defaults variables to empty array', () => {
    const { value } = templateSchema.validate(validTemplate);
    expect(value.variables).toEqual([]);
  });

  it('accepts language en', () => {
    const { error } = templateSchema.validate({ ...validTemplate, language: 'en' });
    expect(error).toBeUndefined();
  });

  it('rejects invalid language', () => {
    const { error } = templateSchema.validate({ ...validTemplate, language: 'es' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('language');
  });

  it('accepts all valid categories', () => {
    for (const category of VALID_TEMPLATE_CATEGORIES) {
      const { error } = templateSchema.validate({ ...validTemplate, category });
      expect(error).toBeUndefined();
    }
  });

  it('rejects invalid category', () => {
    const { error } = templateSchema.validate({ ...validTemplate, category: 'unknown' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('category');
  });

  it('rejects missing name', () => {
    const { error } = templateSchema.validate({ body: 'Hello', category: 'custom' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects empty name', () => {
    const { error } = templateSchema.validate({ ...validTemplate, name: '' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects name shorter than 2 characters', () => {
    const { error } = templateSchema.validate({ ...validTemplate, name: 'A' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects name longer than 100 characters', () => {
    const { error } = templateSchema.validate({ ...validTemplate, name: 'N'.repeat(101) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects missing body', () => {
    const { error } = templateSchema.validate({ name: 'Test', category: 'custom' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('body');
  });

  it('rejects empty body', () => {
    const { error } = templateSchema.validate({ ...validTemplate, body: '' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('body');
  });

  it('rejects body longer than 1000 characters', () => {
    const { error } = templateSchema.validate({ ...validTemplate, body: 'B'.repeat(1001) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('body');
  });

  it('allows null description', () => {
    const { error } = templateSchema.validate({ ...validTemplate, description: null });
    expect(error).toBeUndefined();
  });

  it('allows empty description', () => {
    const { error } = templateSchema.validate({ ...validTemplate, description: '' });
    expect(error).toBeUndefined();
  });

  it('rejects description over 500 characters', () => {
    const { error } = templateSchema.validate({ ...validTemplate, description: 'D'.repeat(501) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('description');
  });

  it('accepts variables array', () => {
    const { error } = templateSchema.validate({
      ...validTemplate,
      variables: ['name', 'date', 'building'],
    });
    expect(error).toBeUndefined();
  });

  it('rejects more than 20 variables', () => {
    const vars = Array.from({ length: 21 }, (_, i) => `var${i}`);
    const { error } = templateSchema.validate({ ...validTemplate, variables: vars });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('variables');
  });
});

describe('updateTemplateSchema', () => {
  it('validates empty object', () => {
    const { error } = updateTemplateSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('validates partial update with just name', () => {
    const { error, value } = updateTemplateSchema.validate({ name: 'New Name' });
    expect(error).toBeUndefined();
    expect(value.name).toBe('New Name');
  });

  it('validates partial update with just body', () => {
    const { error } = updateTemplateSchema.validate({ body: 'Updated body text.' });
    expect(error).toBeUndefined();
  });

  it('still validates name min length', () => {
    const { error } = updateTemplateSchema.validate({ name: 'A' });
    expect(error).toBeDefined();
  });

  it('still validates body min length', () => {
    const { error } = updateTemplateSchema.validate({ body: '' });
    expect(error).toBeDefined();
  });

  it('still validates language enum', () => {
    const { error } = updateTemplateSchema.validate({ language: 'de' });
    expect(error).toBeDefined();
  });

  it('still validates category enum', () => {
    const { error } = updateTemplateSchema.validate({ category: 'invalid' });
    expect(error).toBeDefined();
  });

  it('still validates description max length', () => {
    const { error } = updateTemplateSchema.validate({ description: 'D'.repeat(501) });
    expect(error).toBeDefined();
  });

  it('still validates variables max', () => {
    const vars = Array.from({ length: 21 }, (_, i) => `var${i}`);
    const { error } = updateTemplateSchema.validate({ variables: vars });
    expect(error).toBeDefined();
  });
});

describe('campaignSchema', () => {
  const validCampaign = {
    name: 'Rappel loyer juillet',
    targetAudience: 'all_tenants',
    scheduleType: 'once',
    scheduledAt: '2026-06-28T09:00:00.000Z',
  };

  it('validates a minimal once campaign', () => {
    const { error, value } = campaignSchema.validate(validCampaign);
    expect(error).toBeUndefined();
    expect(value.name).toBe('Rappel loyer juillet');
    expect(value.scheduleType).toBe('once');
    expect(value.templateData).toEqual({});
  });

  it('validates a full campaign with all fields', () => {
    const full = {
      ...validCampaign,
      description: 'Rappel mensuel pour juillet 2026',
      templateId: '550e8400-e29b-41d4-a716-446655440000',
      buildingId: '550e8400-e29b-41d4-a716-446655440001',
      templateData: { month: 'juillet', amount: '850$' },
    };
    const { error, value } = campaignSchema.validate(full);
    expect(error).toBeUndefined();
    expect(value.description).toBe('Rappel mensuel pour juillet 2026');
    expect(value.templateData.month).toBe('juillet');
  });

  it('defaults scheduleType to once', () => {
    const { value } = campaignSchema.validate({
      name: 'Test',
      targetAudience: 'all_tenants',
      scheduledAt: '2026-06-28T09:00:00.000Z',
    });
    expect(value.scheduleType).toBe('once');
  });

  it('defaults templateData to empty object', () => {
    const { value } = campaignSchema.validate(validCampaign);
    expect(value.templateData).toEqual({});
  });

  it('validates a recurring campaign with cron expression', () => {
    const { error } = campaignSchema.validate({
      name: 'Weekly reminder',
      targetAudience: 'all_tenants',
      scheduleType: 'recurring',
      cronExpression: '0 9 * * 1',
    });
    expect(error).toBeUndefined();
  });

  it('rejects recurring campaign without cron expression', () => {
    const { error } = campaignSchema.validate({
      name: 'Weekly reminder',
      targetAudience: 'all_tenants',
      scheduleType: 'recurring',
    });
    expect(error).toBeDefined();
  });

  it('rejects missing name', () => {
    const { error } = campaignSchema.validate({
      targetAudience: 'all_tenants',
      scheduledAt: '2026-06-28T09:00:00.000Z',
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects empty name', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, name: '' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects name shorter than 2 characters', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, name: 'A' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects name longer than 200 characters', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, name: 'N'.repeat(201) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects missing targetAudience', () => {
    const { error } = campaignSchema.validate({
      name: 'Test',
      scheduledAt: '2026-06-28T09:00:00.000Z',
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('targetAudience');
  });

  it('accepts all valid audiences', () => {
    for (const audience of VALID_AUDIENCES) {
      const { error } = campaignSchema.validate({ ...validCampaign, targetAudience: audience });
      expect(error).toBeUndefined();
    }
  });

  it('rejects invalid targetAudience', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, targetAudience: 'everyone' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('targetAudience');
  });

  it('accepts null templateId', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, templateId: null });
    expect(error).toBeUndefined();
  });

  it('rejects invalid templateId', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, templateId: 'not-a-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('templateId');
  });

  it('accepts null buildingId', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, buildingId: null });
    expect(error).toBeUndefined();
  });

  it('rejects invalid buildingId', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, buildingId: 'bad-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('buildingId');
  });

  it('accepts all valid schedule types', () => {
    // recurring requires cronExpression
    const { error: onceError } = campaignSchema.validate({ ...validCampaign, scheduleType: 'once' });
    expect(onceError).toBeUndefined();
    const { error: recurringError } = campaignSchema.validate({
      ...validCampaign,
      scheduleType: 'recurring',
      cronExpression: '0 9 * * 1',
    });
    expect(recurringError).toBeUndefined();
  });

  it('rejects invalid scheduleType', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, scheduleType: 'daily' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('scheduleType');
  });

  it('allows null description', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, description: null });
    expect(error).toBeUndefined();
  });

  it('allows empty description', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, description: '' });
    expect(error).toBeUndefined();
  });

  it('rejects description over 1000 characters', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, description: 'D'.repeat(1001) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('description');
  });

  it('allows null cronExpression for once type', () => {
    const { error } = campaignSchema.validate({ ...validCampaign, cronExpression: null });
    expect(error).toBeUndefined();
  });

  it('rejects cronExpression over 100 characters', () => {
    const { error } = campaignSchema.validate({
      ...validCampaign,
      scheduleType: 'recurring',
      cronExpression: 'a'.repeat(101),
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('cronExpression');
  });

  it('allows templateData as object', () => {
    const { error } = campaignSchema.validate({
      ...validCampaign,
      templateData: { key: 'value' },
    });
    expect(error).toBeUndefined();
  });
});

describe('updateCampaignSchema', () => {
  it('validates empty object', () => {
    const { error } = updateCampaignSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('validates partial update with just name', () => {
    const { error, value } = updateCampaignSchema.validate({ name: 'Updated Name' });
    expect(error).toBeUndefined();
    expect(value.name).toBe('Updated Name');
  });

  it('validates partial update with targetAudience', () => {
    const { error } = updateCampaignSchema.validate({ targetAudience: 'building_tenants' });
    expect(error).toBeUndefined();
  });

  it('still validates name min length', () => {
    const { error } = updateCampaignSchema.validate({ name: 'A' });
    expect(error).toBeDefined();
  });

  it('still validates targetAudience enum', () => {
    const { error } = updateCampaignSchema.validate({ targetAudience: 'invalid' });
    expect(error).toBeDefined();
  });

  it('still validates scheduleType enum', () => {
    const { error } = updateCampaignSchema.validate({ scheduleType: 'daily' });
    expect(error).toBeDefined();
  });

  it('still validates buildingId UUID', () => {
    const { error } = updateCampaignSchema.validate({ buildingId: 'bad-uuid' });
    expect(error).toBeDefined();
  });

  it('still validates templateId UUID', () => {
    const { error } = updateCampaignSchema.validate({ templateId: 'bad-uuid' });
    expect(error).toBeDefined();
  });

  it('allows null buildingId', () => {
    const { error } = updateCampaignSchema.validate({ buildingId: null });
    expect(error).toBeUndefined();
  });

  it('allows null templateId', () => {
    const { error } = updateCampaignSchema.validate({ templateId: null });
    expect(error).toBeUndefined();
  });

  it('allows updating scheduledAt', () => {
    const { error } = updateCampaignSchema.validate({
      scheduledAt: '2026-07-01T09:00:00.000Z',
    });
    expect(error).toBeUndefined();
  });

  it('allows null scheduledAt', () => {
    const { error } = updateCampaignSchema.validate({ scheduledAt: null });
    expect(error).toBeUndefined();
  });

  it('still validates description max length', () => {
    const { error } = updateCampaignSchema.validate({ description: 'D'.repeat(1001) });
    expect(error).toBeDefined();
  });
});

describe('activateCampaignSchema', () => {
  it('accepts active status', () => {
    const { error } = activateCampaignSchema.validate({ status: 'active' });
    expect(error).toBeUndefined();
  });

  it('accepts paused status', () => {
    const { error } = activateCampaignSchema.validate({ status: 'paused' });
    expect(error).toBeUndefined();
  });

  it('accepts cancelled status', () => {
    const { error } = activateCampaignSchema.validate({ status: 'cancelled' });
    expect(error).toBeUndefined();
  });

  it('rejects invalid status', () => {
    const { error } = activateCampaignSchema.validate({ status: 'draft' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  it('rejects completed status', () => {
    const { error } = activateCampaignSchema.validate({ status: 'completed' });
    expect(error).toBeDefined();
  });

  it('rejects missing status', () => {
    const { error } = activateCampaignSchema.validate({});
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  it('rejects empty status', () => {
    const { error } = activateCampaignSchema.validate({ status: '' });
    expect(error).toBeDefined();
  });
});

describe('VALID_TEMPLATE_CATEGORIES', () => {
  it('includes visit_reminder', () => {
    expect(VALID_TEMPLATE_CATEGORIES).toContain('visit_reminder');
  });

  it('includes lease_renewal', () => {
    expect(VALID_TEMPLATE_CATEGORIES).toContain('lease_renewal');
  });

  it('includes payment_reminder', () => {
    expect(VALID_TEMPLATE_CATEGORIES).toContain('payment_reminder');
  });

  it('includes custom', () => {
    expect(VALID_TEMPLATE_CATEGORIES).toContain('custom');
  });
});

describe('VALID_AUDIENCES', () => {
  it('includes all_tenants', () => {
    expect(VALID_AUDIENCES).toContain('all_tenants');
  });

  it('includes building_tenants', () => {
    expect(VALID_AUDIENCES).toContain('building_tenants');
  });

  it('includes specific_leads', () => {
    expect(VALID_AUDIENCES).toContain('specific_leads');
  });
});

describe('VALID_SCHEDULE_TYPES', () => {
  it('includes once', () => {
    expect(VALID_SCHEDULE_TYPES).toContain('once');
  });

  it('includes recurring', () => {
    expect(VALID_SCHEDULE_TYPES).toContain('recurring');
  });
});

describe('VALID_CAMPAIGN_STATUSES', () => {
  it('includes all expected statuses', () => {
    expect(VALID_CAMPAIGN_STATUSES).toContain('draft');
    expect(VALID_CAMPAIGN_STATUSES).toContain('active');
    expect(VALID_CAMPAIGN_STATUSES).toContain('paused');
    expect(VALID_CAMPAIGN_STATUSES).toContain('completed');
    expect(VALID_CAMPAIGN_STATUSES).toContain('cancelled');
  });
});
