/**
 * Tests for sms.service.js
 * Covers: sendVisitConfirmation, sendTenantConfirmationRequest,
 *         sendOccupantAccessRequest, sendMorningOfReminder,
 *         sendPostVisitSurvey, handleOccupantReply
 */

// ─── Mocks ──────────────────────────────────────────────────────────────────────

const mockState = {
  limitResults: [],
  limitIndex: 0,
};

const chain = {};

const resetChain = () => {
  chain.select = jest.fn(() => chain);
  chain.from = jest.fn(() => chain);
  chain.leftJoin = jest.fn(() => chain);
  chain.where = jest.fn(() => chain);
  chain.orderBy = jest.fn(() => chain);
  chain.limit = jest.fn(() => {
    const idx = mockState.limitIndex;
    mockState.limitIndex++;
    const result = idx < mockState.limitResults.length
      ? mockState.limitResults[idx]
      : [];
    return Promise.resolve(result);
  });
  chain.insert = jest.fn(() => chain);
  chain.values = jest.fn(() => Promise.resolve(undefined));
  chain.update = jest.fn(() => chain);
  chain.set = jest.fn(() => chain);
};

resetChain();

jest.mock('../src/database/connection', () => ({
  db: chain,
}));

jest.mock('../src/services/twilio.service', () => ({
  sendSMS: jest.fn(),
  handleIncomingMessage: jest.fn(),
  initTwilio: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { db } = require('../src/database/connection');
const { sendSMS, handleIncomingMessage } = require('../src/services/twilio.service');
const smsService = require('../src/services/sms.service');

// ─── Helpers ────────────────────────────────────────────────────────────────────

const defaultVisit = {
  id: 1,
  dateTime: new Date('2026-05-01T10:00:00Z').toISOString(),
  confirmationToken: 'tok-abc123',
  tenantConfirmed: false,
  occupantNotified: false,
  isActive: true,
  employeeId: 'e1',
  leadId: 'l1',
  unitId: 'u1',
};

const defaultEmployee = {
  id: 'e1',
  phone: '+15145550001',
  firstName: 'Marie',
  lastName: 'Tremblay',
};

const defaultLead = {
  id: 'l1',
  fullName: 'Jean Dupuis',
  phone: '+15145550002',
  language: 'fr',
};

const defaultUnit = {
  id: 'u1',
  label: '4A',
  buildingId: 'b1',
  tenantPhone: null,
  tenantLeaseEnd: null,
};

const defaultBuilding = {
  id: 'b1',
  name: 'Le Grand',
};

/**
 * Build a getVisitContext result row.
 * Pass null to exclude a relation entirely (e.g. makeRow({ employee: null })).
 */
const makeRow = (overrides = {}) => ({
  visit: { ...defaultVisit, ...(overrides.visit || {}) },
  employee: overrides.employee === null ? null : { ...defaultEmployee, ...(overrides.employee || {}) },
  lead: overrides.lead === null ? null : { ...defaultLead, ...(overrides.lead || {}) },
  unit: overrides.unit === null ? null : { ...defaultUnit, ...(overrides.unit || {}) },
  building: overrides.building === null ? null : { ...defaultBuilding, ...(overrides.building || {}) },
});

const setupDb = (contextRows = [], extraLimitResults = []) => {
  mockState.limitIndex = 0;
  mockState.limitResults = [contextRows, ...extraLimitResults];
};

beforeEach(() => {
  jest.clearAllMocks();
  resetChain();
  setupDb([]);
  sendSMS.mockResolvedValue({ success: true, sid: 'SM123', status: 'queued' });
  handleIncomingMessage.mockReturnValue({ action: null });
});

// ─── sendVisitConfirmation ─────────────────────────────────────────────────────

describe('sendVisitConfirmation', () => {
  it('returns error when visit not found', async () => {
    setupDb([]);

    const result = await smsService.sendVisitConfirmation(999);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
  });

  it('returns error when visit is soft-deleted', async () => {
    setupDb([makeRow({ visit: { isActive: false } })]);

    const result = await smsService.sendVisitConfirmation(1);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
    expect(sendSMS).not.toHaveBeenCalled();
  });

  it('returns error when employee is missing', async () => {
    setupDb([makeRow({ employee: null })]);

    const result = await smsService.sendVisitConfirmation(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing related data/);
  });

  it('returns error when lead is missing', async () => {
    setupDb([makeRow({ lead: null })]);

    const result = await smsService.sendVisitConfirmation(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing related data/);
  });

  it('returns error when building is missing', async () => {
    setupDb([makeRow({ building: null })]);

    const result = await smsService.sendVisitConfirmation(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing related data/);
  });

  it('sends SMS and logs when context is complete', async () => {
    setupDb([makeRow()]);

    const result = await smsService.sendVisitConfirmation(1);

    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledTimes(1);
    expect(sendSMS).toHaveBeenCalledWith('+15145550001', expect.stringContaining('Visite planifiée'));
    expect(db.values).toHaveBeenCalledTimes(1);
  });

  it('logs failed SMS correctly', async () => {
    setupDb([makeRow()]);
    sendSMS.mockResolvedValue({ success: false, error: 'Twilio down', status: 'failed' });

    const result = await smsService.sendVisitConfirmation(1);

    expect(result.success).toBe(false);
    expect(db.values).toHaveBeenCalledTimes(1);
  });

  it('handles unexpected errors gracefully', async () => {
    setupDb([makeRow()]);
    sendSMS.mockRejectedValue(new Error('DB crash'));

    const result = await smsService.sendVisitConfirmation(1);

    expect(result.success).toBe(false);
    expect(result.error).toBe('DB crash');
  });
});

// ─── sendTenantConfirmationRequest ──────────────────────────────────────────────

describe('sendTenantConfirmationRequest', () => {
  it('returns error when visit not found', async () => {
    setupDb([]);

    const result = await smsService.sendTenantConfirmationRequest(999);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
  });

  it('returns error when visit is soft-deleted', async () => {
    setupDb([makeRow({ visit: { isActive: false } })]);

    const result = await smsService.sendTenantConfirmationRequest(1);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
    expect(sendSMS).not.toHaveBeenCalled();
  });

  it('returns error when lead phone is missing', async () => {
    setupDb([makeRow({ lead: { phone: null } })]);

    const result = await smsService.sendTenantConfirmationRequest(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing lead phone/);
  });

  it('sends French confirmation by default', async () => {
    setupDb([makeRow()]);

    const result = await smsService.sendTenantConfirmationRequest(1);

    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledWith(
      '+15145550002',
      expect.stringContaining('Visite confirmée'),
    );
  });

  it('sends English confirmation when lead language is en', async () => {
    setupDb([makeRow({ lead: { language: 'en' } })]);

    const result = await smsService.sendTenantConfirmationRequest(1);

    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledWith(
      '+15145550002',
      expect.stringContaining('Visit confirmed'),
    );
  });
});

// ─── sendOccupantAccessRequest ──────────────────────────────────────────────────

describe('sendOccupantAccessRequest', () => {
  it('returns error when visit not found', async () => {
    setupDb([]);

    const result = await smsService.sendOccupantAccessRequest(999);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
  });

  it('returns error when visit is soft-deleted', async () => {
    setupDb([makeRow({ visit: { isActive: false }, unit: { tenantPhone: '+151****0099' } })]);

    const result = await smsService.sendOccupantAccessRequest(1);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
    expect(sendSMS).not.toHaveBeenCalled();
  });

  it('returns error when unit is missing', async () => {
    setupDb([makeRow({ unit: null })]);

    const result = await smsService.sendOccupantAccessRequest(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing unit or building/);
  });

  it('returns error when building is missing', async () => {
    setupDb([makeRow({ building: null, unit: { tenantPhone: '+15145550099' } })]);

    const result = await smsService.sendOccupantAccessRequest(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing unit or building/);
  });

  it('returns error when unit has no tenant phone', async () => {
    setupDb([makeRow()]);

    const result = await smsService.sendOccupantAccessRequest(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/No occupant phone/);
  });

  it('returns error when occupant lease has ended', async () => {
    setupDb([makeRow({
      unit: { tenantPhone: '+15145550099', tenantLeaseEnd: '2020-01-01' },
    })]);

    const result = await smsService.sendOccupantAccessRequest(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/lease has ended/);
  });

  it('sends French access request for future visit', async () => {
    setupDb([makeRow({
      visit: { dateTime: new Date('2099-06-01T10:00:00Z').toISOString() },
      unit: { tenantPhone: '+15145550099' },
    })]);

    const result = await smsService.sendOccupantAccessRequest(1, 'fr');

    expect(result.success).toBe(true);
    expect(result.needsNotice).toBe(false);
    expect(sendSMS).toHaveBeenCalledWith('+15145550099', expect.stringContaining('🔑'));
  });

  it('detects short-notice visit (< 24h)', async () => {
    const soon = new Date(Date.now() + 3600000).toISOString();
    setupDb([makeRow({
      visit: { dateTime: soon },
      unit: { tenantPhone: '+15145550099' },
    })]);

    const result = await smsService.sendOccupantAccessRequest(1, 'fr');

    expect(result.success).toBe(true);
    expect(result.needsNotice).toBe(true);
  });

  it('sends English message when lang=en', async () => {
    setupDb([makeRow({
      visit: { dateTime: new Date('2099-06-01T10:00:00Z').toISOString() },
      unit: { tenantPhone: '+15145550099' },
    })]);

    const result = await smsService.sendOccupantAccessRequest(1, 'en');

    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledWith('+15145550099', expect.stringContaining('apartment 4A'));
  });
});

// ─── handleOccupantReply ────────────────────────────────────────────────────────

describe('handleOccupantReply', () => {
  it('returns error when reply is unrecognised', async () => {
    handleIncomingMessage.mockReturnValue({ action: null });

    const result = await smsService.handleOccupantReply('+15145550099', 'hello');

    expect(result.success).toBe(false);
    expect(result.error).toBe('Unrecognised reply');
    expect(db.values).toHaveBeenCalled();
  });

  it('returns error when no unit found for phone', async () => {
    handleIncomingMessage.mockReturnValue({ action: 'yes' });
    setupDb([], [[], []]);

    const result = await smsService.handleOccupantReply('+15145550099', '1');

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/No unit found/);
  });
});

// ─── sendMorningOfReminder ─────────────────────────────────────────────────────

describe('sendMorningOfReminder', () => {
  it('returns error when visit not found', async () => {
    setupDb([]);

    const result = await smsService.sendMorningOfReminder(999);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
  });

  it('returns error when employee missing', async () => {
    setupDb([makeRow({ employee: null })]);

    const result = await smsService.sendMorningOfReminder(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing employee/);
  });

  it('sends positive reminder when tenant confirmed', async () => {
    setupDb([makeRow({ visit: { tenantConfirmed: true } })]);

    const result = await smsService.sendMorningOfReminder(1);

    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledWith('+15145550001', expect.stringContaining('✅ Rappel'));
  });

  it('sends warning when tenant has NOT confirmed', async () => {
    setupDb([makeRow({ visit: { tenantConfirmed: false } })]);

    const result = await smsService.sendMorningOfReminder(1);

    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledWith('+15145550001', expect.stringContaining('⚠️'));
  });

  it('handles unexpected errors gracefully', async () => {
    setupDb([makeRow()]);
    sendSMS.mockRejectedValue(new Error('Network failure'));

    const result = await smsService.sendMorningOfReminder(1);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Network failure');
  });
});

// ─── sendPostVisitSurvey ───────────────────────────────────────────────────────

describe('sendPostVisitSurvey', () => {
  it('returns error when visit not found', async () => {
    setupDb([]);

    const result = await smsService.sendPostVisitSurvey(999);

    expect(result.success).toBe(false);
    expect(result.error).toBe('Visit not found');
  });

  it('returns error when employee missing', async () => {
    setupDb([makeRow({ employee: null })]);

    const result = await smsService.sendPostVisitSurvey(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing employee or lead/);
  });

  it('returns error when lead missing', async () => {
    setupDb([makeRow({ lead: null })]);

    const result = await smsService.sendPostVisitSurvey(1);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Missing employee or lead/);
  });

  it('sends survey SMS to employee', async () => {
    setupDb([makeRow()]);

    const result = await smsService.sendPostVisitSurvey(1);

    expect(result.success).toBe(true);
    expect(sendSMS).toHaveBeenCalledWith(
      '+15145550001',
      expect.stringContaining('Comment'),
    );
  });
});
