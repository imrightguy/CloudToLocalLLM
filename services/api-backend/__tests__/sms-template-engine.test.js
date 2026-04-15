const {
  validateTemplateRender,
  addToOptOut,
  isOptedOut,
  handleOptOutReply,
  isWithinBusinessHours,
  getNextBusinessHour,
  renderTemplate,
} = require('../src/services/sms.service');

const mockState = { limitResults: [], limitIndex: 0 };
const chain = {};
const resetChain = () => {
  chain.select = jest.fn(() => chain);
  chain.from = jest.fn(() => chain);
  chain.leftJoin = jest.fn(() => chain);
  chain.where = jest.fn(() => chain);
  chain.orderBy = jest.fn(() => chain);
  chain.limit = jest.fn(() => {
    const idx = mockState.limitIndex++;
    return Promise.resolve(idx < mockState.limitResults.length ? mockState.limitResults[idx] : []);
  });
  chain.insert = jest.fn(() => chain);
  chain.values = jest.fn(() => Promise.resolve(undefined));
  chain.update = jest.fn(() => chain);
  chain.set = jest.fn(() => chain);
};
resetChain();

jest.mock('../src/database/connection', () => ({ db: chain }));
jest.mock('../src/services/twilio.service', () => ({
  sendSMS: jest.fn().mockResolvedValue({ success: true, sid: 'SM123', status: 'sent' }),
  handleIncomingMessage: jest.fn(),
  initTwilio: jest.fn(),
}));
jest.mock('../src/database/schema', () => ({
  visitsTable: {},
  smsLogsTable: {},
  smsOptOutsTable: { phoneNumber: 'phoneNumber', reason: 'reason', isActive: 'isActive' },
  employeesTable: {},
  leadsTable: {},
  unitsTable: {},
  buildingsTable: {},
  usersTable: {},
  smsTemplatesTable: {},
  smsCampaignsTable: {},
  smsQueueTable: {},
  leasesTable: {},
}));
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() }));

const { sendSMS } = require('../src/services/twilio.service');

beforeEach(() => {
  jest.clearAllMocks();
  mockState.limitResults = [];
  mockState.limitIndex = 0;
  resetChain();
});

describe('validateTemplateRender', () => {
  it('returns valid when no unreplaced variables', () => {
    const result = validateTemplateRender('Bonjour Jean, votre visite est a 123 rue Sherbrooke.');
    expect(result.valid).toBe(true);
    expect(result.unreplacedVariables).toEqual([]);
  });

  it('returns invalid with unreplaced variable names', () => {
    const result = validateTemplateRender('Bonjour {{lead_name}}, votre visite est a {{address}}.');
    expect(result.valid).toBe(false);
    expect(result.unreplacedVariables).toContain('lead_name');
    expect(result.unreplacedVariables).toContain('address');
  });

  it('returns valid for empty string', () => {
    expect(validateTemplateRender('').valid).toBe(true);
  });

  it('returns valid after rendering all variables', () => {
    const rendered = renderTemplate('Bonjour {{name}}, rdv a {{address}}.', { name: 'Jean', address: '123 rue' });
    const result = validateTemplateRender(rendered);
    expect(result.valid).toBe(true);
  });
});

describe('addToOptOut', () => {
  it('adds phone to opt-out list', async () => {
    mockState.limitResults = [[]];
    const result = await addToOptOut('+15145550001');
    expect(result.success).toBe(true);
    expect(result.alreadyOptedOut).toBe(false);
    expect(chain.insert).toHaveBeenCalled();
  });

  it('returns alreadyOptedOut if phone already opted out', async () => {
    mockState.limitResults = [[{ phoneNumber: '+15145550001', isActive: true }]];
    const result = await addToOptOut('+15145550001');
    expect(result.success).toBe(true);
    expect(result.alreadyOptedOut).toBe(true);
  });
});

describe('isOptedOut', () => {
  it('returns true if phone is opted out', async () => {
    mockState.limitResults = [[{ phoneNumber: '+15145550001', isActive: true }]];
    const result = await isOptedOut('+15145550001');
    expect(result).toBe(true);
  });

  it('returns false if phone is not opted out', async () => {
    mockState.limitResults = [[]];
    const result = await isOptedOut('+15145550001');
    expect(result).toBe(false);
  });
});

describe('handleOptOutReply', () => {
  it('adds to opt-out and sends confirmation SMS', async () => {
    mockState.limitResults = [[]];
    const result = await handleOptOutReply('+15145550001');
    expect(result.success).toBe(true);
    expect(result.action).toBe('opted_out');
    expect(sendSMS).toHaveBeenCalledWith(
      '+15145550001',
      expect.stringContaining('desabonne'),
    );
  });
});

describe('isWithinBusinessHours', () => {
  it('returns true during weekday business hours (10am)', () => {
    const date = new Date('2026-04-15T14:00:00Z');
    expect(isWithinBusinessHours(date)).toBe(true);
  });

  it('returns false before 8am', () => {
    const date = new Date('2026-04-15T12:00:00Z');
    expect(isWithinBusinessHours(date)).toBe(false);
  });

  it('returns false after 9pm', () => {
    const date = new Date('2026-04-16T02:00:00Z');
    expect(isWithinBusinessHours(date)).toBe(false);
  });

  it('returns false on Sunday', () => {
    const date = new Date('2026-04-12T14:00:00Z');
    expect(isWithinBusinessHours(date)).toBe(false);
  });

  it('returns true on Saturday morning (8am-1pm)', () => {
    const date = new Date('2026-04-11T14:00:00Z');
    expect(isWithinBusinessHours(date)).toBe(true);
  });
});

describe('getNextBusinessHour', () => {
  it('returns current time if within business hours', () => {
    const date = new Date('2026-04-15T14:00:00Z');
    const next = getNextBusinessHour(date);
    expect(next.getTime()).toBeLessThanOrEqual(date.getTime() + 60000);
  });

  it('returns 8am next day if after 9pm', () => {
    const date = new Date('2026-04-16T02:00:00Z');
    const next = getNextBusinessHour(date);
    expect(next.getTime()).toBeGreaterThan(date.getTime());
  });

  it('returns Monday 8am if Sunday', () => {
    const date = new Date('2026-04-12T14:00:00Z');
    const next = getNextBusinessHour(date);
    expect(next.getTime()).toBeGreaterThan(date.getTime());
  });
});
