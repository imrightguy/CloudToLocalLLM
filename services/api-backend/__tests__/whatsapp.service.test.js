jest.mock('twilio', () => {
  const mockCreate = jest.fn();
  return jest.fn(() => ({
    messages: { create: mockCreate },
  }));
});

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

jest.mock('../src/database/connection', () => ({
  db: {
    insert: jest.fn(() => ({
      values: jest.fn(() => Promise.resolve([{ id: 1 }])),
    })),
  },
}));

jest.mock('../src/database/schema', () => ({
  communicationLogsTable: {
    leadId: 'leadId',
    employeeId: 'employeeId',
    type: 'type',
    direction: 'direction',
    content: 'content',
    attachments: 'attachments',
    status: 'status',
    metadata: 'metadata',
  },
}));

const twilio = require('twilio');
const {
  initWhatsApp,
  isReady,
  sendWhatsAppMessage,
  sendWhatsAppTemplate,
  parseIncomingWhatsApp,
  formatWhatsAppRecipient,
  getWhatsAppSender,
  t,
  detectLanguage,
  i18n,
  WHATSAPP_TYPE,
} = require('../src/services/whatsapp.service');

let mockCreate;

beforeEach(() => {
  jest.clearAllMocks();
  mockCreate = twilio().messages.create;
  process.env.TWILIO_ACCOUNT_SID = 'AC123';
  process.env.TWILIO_AUTH_TOKEN = 'test_token';
  process.env.TWILIO_WHATSAPP_NUMBER = '+15145551234';
});

describe('initWhatsApp', () => {
  it('initializes successfully with valid credentials', () => {
    const result = initWhatsApp();
    expect(result).toBe(true);
    expect(isReady()).toBe(true);
  });

  it('returns false when credentials are missing', () => {
    delete process.env.TWILIO_ACCOUNT_SID;
    delete process.env.TWILIO_AUTH_TOKEN;
    const result = initWhatsApp();
    expect(result).toBe(false);
    expect(isReady()).toBe(false);
  });

  it('returns false on unexpected error', () => {
    twilio.mockImplementationOnce(() => { throw new Error('crash'); });
    const result = initWhatsApp();
    expect(result).toBe(false);
  });
});

describe('formatWhatsAppRecipient', () => {
  it('adds whatsapp: prefix to plain number', () => {
    expect(formatWhatsAppRecipient('+15145551234')).toBe('whatsapp:+15145551234');
  });

  it('keeps existing whatsapp: prefix', () => {
    expect(formatWhatsAppRecipient('whatsapp:+15145551234')).toBe('whatsapp:+15145551234');
  });

  it('cleans spaces, dashes, parens', () => {
    expect(formatWhatsAppRecipient('+1 (514) 555-1234')).toBe('whatsapp:+15145551234');
  });

  it('returns null for empty input', () => {
    expect(formatWhatsAppRecipient('')).toBeNull();
    expect(formatWhatsAppRecipient(null)).toBeNull();
  });
});

describe('getWhatsAppSender', () => {
  it('returns whatsapp-prefixed number from TWILIO_WHATSAPP_NUMBER', () => {
    process.env.TWILIO_WHATSAPP_NUMBER = '+15145550000';
    expect(getWhatsAppSender()).toBe('whatsapp:+15145550000');
  });

  it('falls back to TWILIO_PHONE_NUMBER', () => {
    delete process.env.TWILIO_WHATSAPP_NUMBER;
    process.env.TWILIO_PHONE_NUMBER = '+15145559999';
    expect(getWhatsAppSender()).toBe('whatsapp:+15145559999');
  });

  it('returns null when no number configured', () => {
    delete process.env.TWILIO_WHATSAPP_NUMBER;
    delete process.env.TWILIO_PHONE_NUMBER;
    expect(getWhatsAppSender()).toBeNull();
  });
});

describe('sendWhatsAppMessage', () => {
  beforeEach(() => {
    initWhatsApp();
  });

  it('sends a message and returns success', async () => {
    mockCreate.mockResolvedValue({ sid: 'SM123', status: 'queued' });
    const result = await sendWhatsAppMessage('+15145559999', 'Hello');
    expect(result.success).toBe(true);
    expect(result.sid).toBe('SM123');
  });

  it('returns error when not initialized', async () => {
    delete process.env.TWILIO_ACCOUNT_SID;
    delete process.env.TWILIO_AUTH_TOKEN;
    initWhatsApp();
    const result = await sendWhatsAppMessage('+15145559999', 'Hello');
    expect(result.success).toBe(false);
    expect(result.error).toMatch(/not initialized/i);
  });

  it('returns error when phone number is missing', async () => {
    const result = await sendWhatsAppMessage('', 'Hello');
    expect(result.success).toBe(false);
  });

  it('returns error when body is missing', async () => {
    const result = await sendWhatsAppMessage('+15145559999', '');
    expect(result.success).toBe(false);
  });

  it('returns error when sender number not configured', async () => {
    delete process.env.TWILIO_WHATSAPP_NUMBER;
    delete process.env.TWILIO_PHONE_NUMBER;
    initWhatsApp();
    const result = await sendWhatsAppMessage('+15145559999', 'Hello');
    expect(result.success).toBe(false);
    expect(result.error).toMatch(/not configured/i);
  });

  it('handles Twilio API errors', async () => {
    mockCreate.mockRejectedValue(new Error('Rate limit'));
    const result = await sendWhatsAppMessage('+15145559999', 'Hello');
    expect(result.success).toBe(false);
    expect(result.error).toBe('Rate limit');
  });
});

describe('sendWhatsAppTemplate', () => {
  beforeEach(() => {
    initWhatsApp();
  });

  it('sends a template message with contentSid', async () => {
    mockCreate.mockResolvedValue({ sid: 'SM Templ', status: 'queued' });
    const result = await sendWhatsAppTemplate('+15145559999', {
      contentSid: 'HXabc123',
      contentVariables: JSON.stringify({ 1: 'John' }),
    });
    expect(result.success).toBe(true);
    expect(mockCreate).toHaveBeenCalledWith(
      expect.objectContaining({ contentSid: 'HXabc123' }),
    );
  });

  it('returns error when neither contentSid nor body provided', async () => {
    const result = await sendWhatsAppTemplate('+15145559999', {});
    expect(result.success).toBe(false);
    expect(result.error).toMatch(/contentSid or body/i);
  });
});

describe('parseIncomingWhatsApp', () => {
  it('maps oui to yes', () => {
    expect(parseIncomingWhatsApp('oui')).toEqual({ action: 'yes', raw: 'oui' });
  });

  it('maps 1 to yes', () => {
    expect(parseIncomingWhatsApp('1')).toEqual({ action: 'yes', raw: '1' });
  });

  it('maps stop to stop', () => {
    expect(parseIncomingWhatsApp('stop')).toEqual({ action: 'stop', raw: 'stop' });
  });

  it('maps aide to help', () => {
    expect(parseIncomingWhatsApp('aide')).toEqual({ action: 'help', raw: 'aide' });
  });

  it('returns null action for unrecognized input', () => {
    expect(parseIncomingWhatsApp('hello world')).toEqual({ action: null, raw: 'hello world' });
  });

  it('handles null/undefined', () => {
    expect(parseIncomingWhatsApp(null)).toEqual({ action: null, raw: '' });
  });

  it('trims and lowercases', () => {
    expect(parseIncomingWhatsApp('  OUI  ')).toEqual({ action: 'yes', raw: 'oui' });
  });
});

describe('i18n', () => {
  it('has French keys for all required strings', () => {
    const requiredKeys = ['welcome', 'askReason', 'askBudget', 'askBuilding', 'suggestVisit', 'visitBooked', 'thankYou', 'fallback', 'optOut', 'help'];
    for (const key of requiredKeys) {
      expect(i18n.fr[key]).toBeDefined();
      expect(typeof i18n.fr[key]).toBe('string');
    }
  });

  it('has matching English keys', () => {
    const frKeys = Object.keys(i18n.fr);
    const enKeys = Object.keys(i18n.en);
    expect(enKeys.sort()).toEqual(frKeys.sort());
  });
});

describe('t', () => {
  it('returns French string by default', () => {
    expect(t('welcome', 'fr')).toBe(i18n.fr.welcome);
  });

  it('returns English string', () => {
    expect(t('welcome', 'en')).toBe(i18n.en.welcome);
  });

  it('falls back to French for unknown language', () => {
    expect(t('welcome', 'de')).toBe(i18n.fr.welcome);
  });

  it('returns key when not found', () => {
    expect(t('nonexistent', 'fr')).toBe('nonexistent');
  });
});

describe('detectLanguage', () => {
  it('detects English from multiple English words', () => {
    expect(detectLanguage('Hello I am looking for an apartment')).toBe('en');
  });

  it('defaults to French', () => {
    expect(detectLanguage('Bonjour je cherche')).toBe('fr');
  });

  it('defaults to French for empty input', () => {
    expect(detectLanguage('')).toBe('fr');
  });
});

describe('WHATSAPP_TYPE', () => {
  it('is whatsapp', () => {
    expect(WHATSAPP_TYPE).toBe('whatsapp');
  });
});
