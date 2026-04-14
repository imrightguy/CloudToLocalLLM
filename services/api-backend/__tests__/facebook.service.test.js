/**
 * Facebook Service Tests
 * Tests for FB Messenger API wrapper — sendTextMessage, sendQuickReplies,
 * sendGenericTemplate, getUserProfile.
 * Uses mocked global fetch.
 *
 * NOTE: facebook.service.js reads FB_PAGE_ACCESS_TOKEN at module-level via
 * destructuring, so we must set env BEFORE requiring and use jest.resetModules()
 * to test the "missing token" path.
 */

const mockFetch = jest.fn();
global.fetch = mockFetch;

const mockLogger = {
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
};
jest.mock('../src/utils/logger', () => mockLogger);

const FB_TOKEN = 'test-fb-page-token-12345';
const FB_API = 'https://graph.facebook.com/v18.0';

const fbApiUrl = () => `${FB_API}/me/messages?access_token=${FB_TOKEN}`;
const fbProfileUrl = (psid) =>
  `${FB_API}/${psid}?fields=first_name,last_name,locale,profile_pic&access_token=${FB_TOKEN}`;

let fbService;

beforeEach(() => {
  jest.resetModules();
  jest.clearAllMocks();
  process.env.FB_PAGE_ACCESS_TOKEN = FB_TOKEN;
  mockFetch.mockReset();
  // Re-require so module picks up env var
  fbService = require('../src/services/facebook.service');
});

afterEach(() => {
  delete process.env.FB_PAGE_ACCESS_TOKEN;
});

// ─── sendTextMessage ───

describe('sendTextMessage', () => {
  it('sends a text message to the Facebook API', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({ recipient_id: '12345', message_id: 'mid.abc' }),
    });

    const result = await fbService.sendTextMessage('12345', 'Bonjour!');

    expect(mockFetch).toHaveBeenCalledTimes(1);
    const [url, options] = mockFetch.mock.calls[0];
    expect(url).toBe(fbApiUrl());
    expect(options.method).toBe('POST');
    const body = JSON.parse(options.body);
    expect(body).toEqual({
      recipient: { id: '12345' },
      messaging_type: 'RESPONSE',
      message: { text: 'Bonjour!' },
    });
    expect(result).toEqual({ recipient_id: '12345', message_id: 'mid.abc' });
  });

  it('throws when FB_PAGE_ACCESS_TOKEN is not set', async () => {
    delete process.env.FB_PAGE_ACCESS_TOKEN;
    jest.resetModules();
    const noTokenService = require('../src/services/facebook.service');

    await expect(noTokenService.sendTextMessage('12345', 'test')).rejects.toThrow(
      'FB_PAGE_ACCESS_TOKEN is not configured',
    );
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('throws on non-OK API response', async () => {
    mockFetch.mockResolvedValue({
      ok: false,
      status: 401,
      text: async () => '{"error":{"message":"Invalid token"}}',
    });

    await expect(fbService.sendTextMessage('12345', 'test')).rejects.toThrow(
      'Facebook Send API error 401',
    );
  });
});

// ─── sendQuickReplies ───

describe('sendQuickReplies', () => {
  it('sends quick reply buttons with text message', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({ recipient_id: '12345', message_id: 'mid.qr1' }),
    });

    const replies = [
      { title: '🇫🇷 Français', payload: 'LANG_FR' },
      { title: '🇬🇧 English', payload: 'LANG_EN' },
    ];

    const result = await fbService.sendQuickReplies('12345', 'Choisissez:', replies);

    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.message.text).toBe('Choisissez:');
    expect(body.message.quick_replies).toEqual([
      { content_type: 'text', title: '🇫🇷 Français', payload: 'LANG_FR' },
      { content_type: 'text', title: '🇬🇧 English', payload: 'LANG_EN' },
    ]);
    expect(result.message_id).toBe('mid.qr1');
  });

  it('maps reply objects to FB quick reply format', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({}),
    });

    const replies = [
      { title: 'Oui', payload: 'YES' },
      { title: 'Non', payload: 'NO' },
      { title: 'Peut-être', payload: 'MAYBE' },
    ];

    await fbService.sendQuickReplies('999', 'Question?', replies);

    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.message.quick_replies).toHaveLength(3);
    body.message.quick_replies.forEach((qr, i) => {
      expect(qr.content_type).toBe('text');
      expect(qr.title).toBe(replies[i].title);
      expect(qr.payload).toBe(replies[i].payload);
    });
  });

  it('throws when FB_PAGE_ACCESS_TOKEN is not set', async () => {
    delete process.env.FB_PAGE_ACCESS_TOKEN;
    jest.resetModules();
    const noTokenService = require('../src/services/facebook.service');

    await expect(
      noTokenService.sendQuickReplies('12345', 'Q?', [{ title: 'A', payload: 'P' }]),
    ).rejects.toThrow('FB_PAGE_ACCESS_TOKEN is not configured');
  });
});

// ─── sendGenericTemplate ───

describe('sendGenericTemplate', () => {
  it('sends a generic template with card elements', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({ recipient_id: '12345', message_id: 'mid.tpl' }),
    });

    const elements = [
      {
        title: '3½ Centre-Ville',
        subtitle: '750$/mois — Disponible immédiatement',
        image_url: 'https://example.com/photo.jpg',
        buttons: [{ type: 'postback', title: 'Réserver', payload: 'BOOK_1' }],
      },
    ];

    const result = await fbService.sendGenericTemplate('12345', elements);

    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.message.attachment.type).toBe('template');
    expect(body.message.attachment.payload.template_type).toBe('generic');
    expect(body.message.attachment.payload.elements).toEqual(elements);
    expect(result.message_id).toBe('mid.tpl');
  });

  it('sends multiple card elements', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({}),
    });

    const elements = [
      { title: 'Unit A' },
      { title: 'Unit B' },
      { title: 'Unit C' },
    ];

    await fbService.sendGenericTemplate('12345', elements);

    const body = JSON.parse(mockFetch.mock.calls[0][1].body);
    expect(body.message.attachment.payload.elements).toHaveLength(3);
  });

  it('throws when FB_PAGE_ACCESS_TOKEN is not set', async () => {
    delete process.env.FB_PAGE_ACCESS_TOKEN;
    jest.resetModules();
    const noTokenService = require('../src/services/facebook.service');

    await expect(
      noTokenService.sendGenericTemplate('12345', [{ title: 'A' }]),
    ).rejects.toThrow('FB_PAGE_ACCESS_TOKEN is not configured');
  });
});

// ─── getUserProfile ───

describe('getUserProfile', () => {
  it('fetches and normalizes user profile', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        first_name: 'Jean',
        last_name: 'Tremblay',
        locale: 'fr_CA',
        profile_pic: 'https://example.com/pic.jpg',
      }),
    });

    const profile = await fbService.getUserProfile('67890');

    expect(mockFetch).toHaveBeenCalledTimes(1);
    expect(mockFetch.mock.calls[0][0]).toBe(fbProfileUrl('67890'));
    expect(profile).toEqual({
      firstName: 'Jean',
      lastName: 'Tremblay',
      locale: 'fr_CA',
      profilePic: 'https://example.com/pic.jpg',
    });
  });

  it('defaults missing profile fields', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({}),
    });

    const profile = await fbService.getUserProfile('11111');

    expect(profile).toEqual({
      firstName: '',
      lastName: '',
      locale: 'fr_CA',
      profilePic: '',
    });
  });

  it('defaults locale to fr_CA when not returned', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({ first_name: 'Bob' }),
    });

    const profile = await fbService.getUserProfile('22222');
    expect(profile.locale).toBe('fr_CA');
    expect(profile.firstName).toBe('Bob');
  });

  it('throws when FB_PAGE_ACCESS_TOKEN is not set', async () => {
    delete process.env.FB_PAGE_ACCESS_TOKEN;
    jest.resetModules();
    const noTokenService = require('../src/services/facebook.service');

    await expect(noTokenService.getUserProfile('12345')).rejects.toThrow(
      'FB_PAGE_ACCESS_TOKEN is not configured',
    );
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('throws on non-OK API response', async () => {
    mockFetch.mockResolvedValue({
      ok: false,
      status: 404,
      text: async () => '{"error":{"message":"User not found"}}',
    });

    await expect(fbService.getUserProfile('00000')).rejects.toThrow(
      'Facebook User API error 404',
    );
  });
});
