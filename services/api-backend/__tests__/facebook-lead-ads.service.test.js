process.env.FB_PAGE_ACCESS_TOKEN = 'test_token';

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
}));

const mockSelectChain = () => {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  return chain;
};

let selectChain;

const mockValuesFn = jest.fn().mockReturnValue({
  returning: jest.fn(() => Promise.resolve([{ id: 'lead-1', fullName: 'Jean Tremblay', source: 'facebook' }])),
});

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({ values: mockValuesFn })),
};

jest.mock('../src/database/connection', () => ({ db: mockDb }));

jest.mock('../src/database/schema', () => ({
  leadsTable: {
    id: 'id', fullName: 'fullName', email: 'email', phone: 'phone',
    budgetCents: 'budgetCents', desiredUnit: 'desiredUnit', source: 'source',
    stage: 'stage', notes: 'notes', tags: 'tags', language: 'language',
    isActive: 'isActive', createdAt: 'createdAt', updatedAt: 'updatedAt',
  },
}));

const { processLeadAdWebhook } = require('../src/services/facebook.service');
const { db } = require('../src/database/connection');

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
  mockValuesFn.mockReturnValue({
    returning: jest.fn(() => Promise.resolve([{ id: 'lead-1', fullName: 'Jean Tremblay', source: 'facebook' }])),
  });
});

describe('processLeadAdWebhook', () => {
  const validLeadData = {
    leadgen_id: '123456',
    field_data: [
      { name: 'full_name', values: ['Jean Tremblay'] },
      { name: 'email', values: ['jean@example.com'] },
      { name: 'phone_number', values: ['+15145551234'] },
      { name: 'desired_unit', values: ['2.5'] },
      { name: 'budget', values: ['1200'] },
    ],
    ad_id: 'ad_001',
    page_id: 'page_001',
    created_time: '2026-04-15T12:00:00+0000',
  };

  it('returns MISSING_LEADGEN_ID when no leadgen_id', async () => {
    const result = await processLeadAdWebhook({});
    expect(result).toEqual({ success: false, reason: 'MISSING_LEADGEN_ID' });
    expect(db.insert).not.toHaveBeenCalled();
  });

  it('returns MISSING_LEADGEN_ID when leadgen_id is null', async () => {
    const result = await processLeadAdWebhook({ leadgen_id: null });
    expect(result).toEqual({ success: false, reason: 'MISSING_LEADGEN_ID' });
  });

  it('returns INVALID_FIELD_DATA when field_data is missing', async () => {
    const result = await processLeadAdWebhook({ leadgen_id: '123' });
    expect(result).toEqual({ success: false, reason: 'INVALID_FIELD_DATA' });
  });

  it('returns INVALID_FIELD_DATA when field_data is not array', async () => {
    const result = await processLeadAdWebhook({ leadgen_id: '123', field_data: 'invalid' });
    expect(result).toEqual({ success: false, reason: 'INVALID_FIELD_DATA' });
  });

  it('returns MISSING_NAME when no full_name field', async () => {
    const result = await processLeadAdWebhook({
      leadgen_id: '123',
      field_data: [{ name: 'email', values: ['t@t.com'] }],
    });
    expect(result).toEqual({ success: false, reason: 'MISSING_NAME' });
  });

  it('returns MISSING_NAME when full_name is empty', async () => {
    const result = await processLeadAdWebhook({
      leadgen_id: '123',
      field_data: [{ name: 'full_name', values: [''] }],
    });
    expect(result).toEqual({ success: false, reason: 'MISSING_NAME' });
  });

  it('deduplicates based on leadgen_id in notes', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'existing-lead' }]);

    const result = await processLeadAdWebhook(validLeadData);

    expect(result).toEqual({ success: false, reason: 'DUPLICATE', existingId: 'existing-lead' });
    expect(mockValuesFn).not.toHaveBeenCalled();
  });

  it('creates a lead with all parsed fields', async () => {
    selectChain.limit.mockResolvedValueOnce([]);

    const result = await processLeadAdWebhook(validLeadData);

    expect(result.success).toBe(true);
    expect(result.lead.id).toBe('lead-1');
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({
        fullName: 'Jean Tremblay',
        email: 'jean@example.com',
        phone: '+15145551234',
        desiredUnit: '2.5',
        budgetCents: 120000,
        source: 'facebook',
        stage: 'nouveau',
        language: 'fr',
        tags: ['facebook_lead_ad'],
      }),
    );
  });

  it('parses budget correctly from string with dollar sign', async () => {
    selectChain.limit.mockResolvedValueOnce([]);

    const result = await processLeadAdWebhook({
      ...validLeadData,
      field_data: [
        { name: 'full_name', values: ['Test User'] },
        { name: 'budget', values: ['$1,500/month'] },
      ],
    });

    expect(result.success).toBe(true);
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({ budgetCents: 150000 }),
    );
  });

  it('handles missing optional fields gracefully', async () => {
    selectChain.limit.mockResolvedValueOnce([]);

    const result = await processLeadAdWebhook({
      leadgen_id: '789',
      field_data: [{ name: 'full_name', values: ['Minimal Lead'] }],
    });

    expect(result.success).toBe(true);
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({
        fullName: 'Minimal Lead',
        email: null,
        phone: null,
        budgetCents: null,
        desiredUnit: null,
      }),
    );
  });

  it('detects English locale and sets language to en', async () => {
    selectChain.limit.mockResolvedValueOnce([]);

    const result = await processLeadAdWebhook({
      leadgen_id: '999',
      field_data: [
        { name: 'full_name', values: ['John'] },
        { name: 'locale', values: ['en_US'] },
      ],
    });

    expect(result.success).toBe(true);
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({ language: 'en' }),
    );
  });

  it('includes ad_id, page_id, and created_time in notes', async () => {
    selectChain.limit.mockResolvedValueOnce([]);

    await processLeadAdWebhook(validLeadData);

    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({
        notes: expect.stringContaining('FB Lead ID: 123456'),
      }),
    );
    const notesArg = mockValuesFn.mock.calls[0][0].notes;
    expect(notesArg).toContain('FB Ad ID: ad_001');
    expect(notesArg).toContain('FB Page ID: page_001');
    expect(notesArg).toContain('FB Created: 2026-04-15T12:00:00+0000');
  });

  it('includes message field_data in notes', async () => {
    selectChain.limit.mockResolvedValueOnce([]);

    await processLeadAdWebhook({
      ...validLeadData,
      field_data: [
        { name: 'full_name', values: ['Jean'] },
        { name: 'message', values: ['I am interested in 2.5'] },
      ],
    });

    const notesArg = mockValuesFn.mock.calls[0][0].notes;
    expect(notesArg).toContain('Message: I am interested in 2.5');
  });

  it('handles DB errors gracefully', async () => {
    selectChain.limit.mockResolvedValueOnce([]);
    mockValuesFn.mockReturnValueOnce({
      returning: jest.fn().mockRejectedValue(new Error('DB connection lost')),
    });

    const result = await processLeadAdWebhook(validLeadData);

    expect(result.success).toBe(false);
    expect(result.reason).toBe('INTERNAL_ERROR');
  });
});

describe('processLeadAdWebhook — field_data aliases', () => {
  beforeEach(() => {
    selectChain.limit.mockResolvedValueOnce([]);
  });

  it('accepts "name" as alias for full_name', async () => {
    const result = await processLeadAdWebhook({
      leadgen_id: 'ALIAS1',
      field_data: [{ name: 'name', values: ['Aliased Name'] }],
    });

    expect(result.success).toBe(true);
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({ fullName: 'Aliased Name' }),
    );
  });

  it('accepts "email_address" as alias for email', async () => {
    const result = await processLeadAdWebhook({
      leadgen_id: 'ALIAS2',
      field_data: [
        { name: 'full_name', values: ['Test'] },
        { name: 'email_address', values: ['alias@test.com'] },
      ],
    });

    expect(result.success).toBe(true);
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({ email: 'alias@test.com' }),
    );
  });

  it('accepts "phone" as alias for phone_number', async () => {
    const result = await processLeadAdWebhook({
      leadgen_id: 'ALIAS3',
      field_data: [
        { name: 'full_name', values: ['Test'] },
        { name: 'phone', values: ['+15145559999'] },
      ],
    });

    expect(result.success).toBe(true);
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({ phone: '+15145559999' }),
    );
  });

  it('accepts "unit_interest" as alias for desired_unit', async () => {
    const result = await processLeadAdWebhook({
      leadgen_id: 'ALIAS4',
      field_data: [
        { name: 'full_name', values: ['Test'] },
        { name: 'unit_interest', values: ['3.5'] },
      ],
    });

    expect(result.success).toBe(true);
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({ desiredUnit: '3.5' }),
    );
  });

  it('accepts "budget_range" as alias for budget', async () => {
    const result = await processLeadAdWebhook({
      leadgen_id: 'ALIAS5',
      field_data: [
        { name: 'full_name', values: ['Test'] },
        { name: 'budget_range', values: ['1200'] },
      ],
    });

    expect(result.success).toBe(true);
    expect(mockValuesFn).toHaveBeenCalledWith(
      expect.objectContaining({ budgetCents: 120000 }),
    );
  });
});
