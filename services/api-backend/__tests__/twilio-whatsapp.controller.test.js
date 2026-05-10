const mockT = jest.fn((key) => `mocked:${key}`);
const mockDetectLanguage = jest.fn(() => 'fr');
const mockParseIncoming = jest.fn();
const mockSendWhatsApp = jest.fn();
const mockLogWhatsApp = jest.fn();

jest.mock('../src/services/whatsapp.service', () => ({
  parseIncomingWhatsApp: mockParseIncoming,
  sendWhatsAppMessage: mockSendWhatsApp,
  logWhatsAppCommunication: mockLogWhatsApp,
  t: mockT,
  detectLanguage: mockDetectLanguage,
  i18n: {},
}));

jest.mock('../src/services/conversation-router.service', () => ({
  findLeadByPhone: jest.fn(),
  logCrossChannelMessage: jest.fn(),
  CHANNEL_TYPES: { WHATSAPP: 'whatsapp', SMS: 'sms' },
}));

jest.mock('../src/services/twilio.service', () => ({
  handleIncomingMessage: jest.fn(),
}));

jest.mock('../src/services/communication-thread.service', () => ({
  refreshCommunicationThread: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const {
  handleIncomingWhatsApp,
  processConversation,
  WHATSAPP_STATES,
  getConversation,
} = require('../src/controllers/twilio-whatsapp.controller');

const { findLeadByPhone } = require('../src/services/conversation-router.service');

function mockRes() {
  return {
    status: jest.fn().mockReturnThis(),
    type: jest.fn().mockReturnThis(),
    send: jest.fn().mockReturnThis(),
  };
}

describe('handleIncomingWhatsApp', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockParseIncoming.mockReturnValue({ action: null, raw: 'hello' });
    mockT.mockImplementation((key) => key);
    mockDetectLanguage.mockReturnValue('fr');
    findLeadByPhone.mockResolvedValue(null);
    mockSendWhatsApp.mockResolvedValue({ success: true });
  });

  it('returns 400 when From is missing', async () => {
    const req = { body: { Body: 'hello' } };
    const res = mockRes();
    await handleIncomingWhatsApp(req, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('handles stop action by sending opt-out', async () => {
    mockParseIncoming.mockReturnValue({ action: 'stop', raw: 'stop' });
    const req = { body: { From: 'whatsapp:+15145551234', Body: 'stop', MessageSid: 'SM1' } };
    const res = mockRes();
    await handleIncomingWhatsApp(req, res);
    expect(mockSendWhatsApp).toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it('processes new conversation and sends welcome reply', async () => {
    const req = { body: { From: 'whatsapp:+15145551234', Body: 'Bonjour', MessageSid: 'SM2', ProfileName: 'Test' } };
    const res = mockRes();
    await handleIncomingWhatsApp(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.type).toHaveBeenCalledWith('text/xml');
  });

  it('returns 200 XML even on error', async () => {
    mockParseIncoming.mockImplementation(() => { throw new Error('unexpected'); });
    const req = { body: { From: 'whatsapp:+15145551234', Body: 'test', MessageSid: 'SM3' } };
    const res = mockRes();
    await handleIncomingWhatsApp(req, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.type).toHaveBeenCalledWith('text/xml');
  });
});

describe('processConversation', () => {
  beforeEach(() => {
    mockT.mockImplementation((key) => key);
  });

  it('transitions from NEW to ASKED_REASON', async () => {
    const conv = { state: WHATSAPP_STATES.NEW, language: 'fr', data: {} };
    const result = await processConversation(conv, 'hello', { action: null, raw: 'hello' }, null);
    expect(conv.state).toBe(WHATSAPP_STATES.ASKED_REASON);
    expect(result).toContain('welcome');
    expect(result).toContain('askReason');
  });

  it('transitions from ASKED_REASON to ASKED_BUDGET', async () => {
    const conv = { state: WHATSAPP_STATES.ASKED_REASON, language: 'fr', data: {} };
    const result = await processConversation(conv, 'demenagement', { action: null, raw: 'demenagement' }, null);
    expect(conv.state).toBe(WHATSAPP_STATES.ASKED_BUDGET);
    expect(result).toContain('askBudget');
  });

  it('transitions from ASKED_BUDGET to ASKED_BUILDING', async () => {
    const conv = { state: WHATSAPP_STATES.ASKED_BUDGET, language: 'fr', data: {} };
    const result = await processConversation(conv, '1200', { action: null, raw: '1200' }, null);
    expect(conv.state).toBe(WHATSAPP_STATES.ASKED_BUILDING);
    expect(result).toContain('askBuilding');
  });

  it('transitions from ASKED_BUILDING to SUGGEST_VISIT', async () => {
    const conv = { state: WHATSAPP_STATES.ASKED_BUILDING, language: 'fr', data: {} };
    const result = await processConversation(conv, 'Immeuble A', { action: null, raw: 'immeuble a' }, null);
    expect(conv.state).toBe(WHATSAPP_STATES.SUGGEST_VISIT);
    expect(result).toContain('suggestVisit');
  });

  it('transitions from SUGGEST_VISIT to DONE on yes', async () => {
    const conv = { state: WHATSAPP_STATES.SUGGEST_VISIT, language: 'fr', data: {} };
    const result = await processConversation(conv, 'oui', { action: 'yes', raw: 'oui' }, null);
    expect(conv.state).toBe(WHATSAPP_STATES.DONE);
    expect(result).toContain('visitBooked');
  });

  it('transitions from SUGGEST_VISIT to DONE on no', async () => {
    const conv = { state: WHATSAPP_STATES.SUGGEST_VISIT, language: 'fr', data: {} };
    const result = await processConversation(conv, 'non', { action: 'no', raw: 'non' }, null);
    expect(conv.state).toBe(WHATSAPP_STATES.DONE);
    expect(result).toContain('thankYou');
  });

  it('returns fallback in DONE state', async () => {
    const conv = { state: WHATSAPP_STATES.DONE, language: 'fr', data: {} };
    const result = await processConversation(conv, 'anything', { action: null, raw: 'anything' }, null);
    expect(result).toContain('fallback');
  });
});

describe('getConversation', () => {
  it('creates a new conversation for unknown phone', () => {
    const conv = getConversation('+15145559999');
    expect(conv.state).toBe(WHATSAPP_STATES.NEW);
    expect(conv.language).toBe('fr');
  });

  it('returns existing conversation', () => {
    const conv1 = getConversation('+15145558888');
    conv1.state = WHATSAPP_STATES.ASKED_BUDGET;
    const conv2 = getConversation('+15145558888');
    expect(conv2.state).toBe(WHATSAPP_STATES.ASKED_BUDGET);
  });
});
