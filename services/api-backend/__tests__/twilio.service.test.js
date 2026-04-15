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

const twilio = require('twilio');
const { initTwilio, sendSMS, handleIncomingMessage } = require('../src/services/twilio.service');

let mockCreate;

beforeEach(() => {
  jest.clearAllMocks();
  mockCreate = twilio().messages.create;
});

describe('initTwilio', () => {
  it('returns true and logs success when credentials are set', () => {
    process.env.TWILIO_ACCOUNT_SID = 'AC123';
    process.env.TWILIO_AUTH_TOKEN = 'token';
    process.env.TWILIO_PHONE_NUMBER = '+15145551234';

    const result = initTwilio();

    expect(result).toBe(true);
    expect(twilio).toHaveBeenCalledWith('AC123', 'token');
  });

  it('returns false when credentials are missing', () => {
    jest.clearAllMocks();
    delete process.env.TWILIO_ACCOUNT_SID;
    delete process.env.TWILIO_AUTH_TOKEN;

    const result = initTwilio();

    expect(result).toBe(false);
    expect(twilio).not.toHaveBeenCalled();
  });

  it('returns false and handles unexpected errors', () => {
    process.env.TWILIO_ACCOUNT_SID = 'AC123';
    process.env.TWILIO_AUTH_TOKEN = 'token';
    twilio.mockImplementationOnce(() => {
      throw new Error('twilio crash');
    });

    const result = initTwilio();

    expect(result).toBe(false);
  });
});

describe('sendSMS', () => {
  beforeEach(() => {
    process.env.TWILIO_ACCOUNT_SID = 'AC123';
    process.env.TWILIO_AUTH_TOKEN = 'token';
    process.env.TWILIO_PHONE_NUMBER = '+15145551234';
    initTwilio();
  });

  it('sends SMS and returns success with sid', async () => {
    mockCreate.mockResolvedValue({ sid: 'SM123', status: 'queued' });

    const result = await sendSMS('+1 (514) 555-0000', 'Hello tenant');

    expect(result.success).toBe(true);
    expect(result.sid).toBe('SM123');
    expect(result.status).toBe('queued');
    expect(mockCreate).toHaveBeenCalledWith({
      body: 'Hello tenant',
      from: '+15145551234',
      to: '+15145550000',
    });
  });

  it('returns false when Twilio not initialized', async () => {
    delete process.env.TWILIO_ACCOUNT_SID;
    delete process.env.TWILIO_AUTH_TOKEN;
    initTwilio();

    const result = await sendSMS('+15145550000', 'test');

    expect(result.success).toBe(false);
    expect(result.error).toBe('Twilio not initialized');
  });

  it('returns false when phone number is missing', async () => {
    const result = await sendSMS('', 'test');

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/required/i);
  });

  it('returns false when body is missing', async () => {
    const result = await sendSMS('+15145550000', '');

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/required/i);
  });

  it('returns false when from number not configured', async () => {
    delete process.env.TWILIO_PHONE_NUMBER;
    initTwilio();

    const result = await sendSMS('+15145550000', 'test');

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/TWILIO_PHONE_NUMBER/i);
  });

  it('handles Twilio API errors gracefully', async () => {
    mockCreate.mockRejectedValue(new Error('Insufficient funds'));

    const result = await sendSMS('+15145550000', 'test');

    expect(result.success).toBe(false);
    expect(result.error).toBe('Insufficient funds');
  });
});

describe('handleIncomingMessage', () => {
  it('maps number 1 to yes', () => {
    expect(handleIncomingMessage('1')).toEqual({ action: 'yes', raw: '1' });
  });

  it('maps number 2 to no', () => {
    expect(handleIncomingMessage('2')).toEqual({ action: 'no', raw: '2' });
  });

  it('maps number 3 to no_show', () => {
    expect(handleIncomingMessage('3')).toEqual({ action: 'no_show', raw: '3' });
  });

  it('maps French oui to yes', () => {
    expect(handleIncomingMessage('oui')).toEqual({ action: 'yes', raw: 'oui' });
  });

  it('maps French non to no', () => {
    expect(handleIncomingMessage('non')).toEqual({ action: 'no', raw: 'non' });
  });

  it('maps y to yes', () => {
    expect(handleIncomingMessage('y')).toEqual({ action: 'yes', raw: 'y' });
  });

  it('maps absent to no_show', () => {
    expect(handleIncomingMessage('absent')).toEqual({ action: 'no_show', raw: 'absent' });
  });

  it('maps pas nécessaire to no', () => {
    expect(handleIncomingMessage('pas nécessaire')).toEqual({ action: 'no', raw: 'pas nécessaire' });
  });

  it('maps intéressé to interested', () => {
    expect(handleIncomingMessage('intéressé')).toEqual({ action: 'interested', raw: 'intéressé' });
  });

  it('returns null action for unrecognized input', () => {
    expect(handleIncomingMessage('hello')).toEqual({ action: null, raw: 'hello' });
  });

  it('handles null/undefined body', () => {
    expect(handleIncomingMessage(null)).toEqual({ action: null, raw: '' });
    expect(handleIncomingMessage(undefined)).toEqual({ action: null, raw: '' });
  });

  it('trims and lowercases input', () => {
    expect(handleIncomingMessage('  OUI  ')).toEqual({ action: 'yes', raw: 'oui' });
    expect(handleIncomingMessage('  YES  ')).toEqual({ action: 'yes', raw: 'yes' });
  });

  it('maps ne s\'est pas présenté to no_show', () => {
    expect(handleIncomingMessage("ne s'est pas présenté")).toEqual({
      action: 'no_show',
      raw: "ne s'est pas présenté",
    });
  });

  it('maps accept to yes', () => {
    expect(handleIncomingMessage('accept')).toEqual({ action: 'yes', raw: 'accept' });
  });

  it('maps accepte to yes', () => {
    expect(handleIncomingMessage('accepte')).toEqual({ action: 'yes', raw: 'accepte' });
  });

  it('maps decline to no', () => {
    expect(handleIncomingMessage('decline')).toEqual({ action: 'no', raw: 'decline' });
  });

  it('maps refuse to no', () => {
    expect(handleIncomingMessage('refuse')).toEqual({ action: 'no', raw: 'refuse' });
  });

  it('maps arrive to arrive', () => {
    expect(handleIncomingMessage('arrive')).toEqual({ action: 'arrive', raw: 'arrive' });
  });

  it('maps arrivé to arrive', () => {
    expect(handleIncomingMessage('arrivé')).toEqual({ action: 'arrive', raw: 'arrivé' });
  });

  it('maps je suis arrivé to arrive', () => {
    expect(handleIncomingMessage('je suis arrivé')).toEqual({ action: 'arrive', raw: 'je suis arrivé' });
  });

  it('maps termine to termine', () => {
    expect(handleIncomingMessage('termine')).toEqual({ action: 'termine', raw: 'termine' });
  });

  it('maps terminé to termine', () => {
    expect(handleIncomingMessage('terminé')).toEqual({ action: 'termine', raw: 'terminé' });
  });

  it('maps fin to termine', () => {
    expect(handleIncomingMessage('fin')).toEqual({ action: 'termine', raw: 'fin' });
  });
});
