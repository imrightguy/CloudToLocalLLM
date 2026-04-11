/**
 * Jest tests for facebook-webhook.controller
 *
 * Covers the GET /webhooks/facebook verification handshake and the
 * POST /webhooks/facebook incoming-event handler.
 */

// ── Set env BEFORE any requires (the controller captures FB_VERIFY_TOKEN at load time) ──
process.env.FB_VERIFY_TOKEN = 'test_verify_token';

// ── Module mocks ──
jest.mock('../src/services/messenger-bot.service', () => ({
  handleIncomingMessage: jest.fn().mockResolvedValue(undefined),
  handlePostback: jest.fn().mockResolvedValue(undefined),
  handleOptIn: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
}));

// ── Imports (after mocks) ──
const { verify, handleWebhook } = require('../src/controllers/facebook-webhook.controller');
const botService = require('../src/services/messenger-bot.service');

// ── Helpers ──
function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  return res;
}

// ════════════════════════════════════════════════════════════════
//  verify (GET handler)
// ════════════════════════════════════════════════════════════════
describe('verify', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 200 with the challenge when mode=subscribe and token matches', () => {
    const req = {
      query: {
        'hub.mode': 'subscribe',
        'hub.verify_token': 'test_verify_token',
        'hub.challenge': 'CHALLENGE_ABC',
      },
    };

    verify(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith('CHALLENGE_ABC');
  });

  it('returns 403 when mode is not subscribe', () => {
    const req = {
      query: {
        'hub.mode': 'unsubscribe',
        'hub.verify_token': 'test_verify_token',
        'hub.challenge': 'CHALLENGE_ABC',
      },
    };

    verify(req, res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.send).toHaveBeenCalledWith('Forbidden');
  });

  it('returns 403 when the token does not match', () => {
    const req = {
      query: {
        'hub.mode': 'subscribe',
        'hub.verify_token': 'wrong_token',
        'hub.challenge': 'CHALLENGE_ABC',
      },
    };

    verify(req, res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.send).toHaveBeenCalledWith('Forbidden');
  });

  it('returns 403 when query params are missing entirely', () => {
    const req = { query: {} };

    verify(req, res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.send).toHaveBeenCalledWith('Forbidden');
  });

  it('returns 403 when mode is missing (undefined)', () => {
    const req = {
      query: {
        'hub.verify_token': 'test_verify_token',
        'hub.challenge': 'CHALLENGE_ABC',
      },
    };

    verify(req, res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.send).toHaveBeenCalledWith('Forbidden');
  });
});

// ════════════════════════════════════════════════════════════════
//  handleWebhook (POST handler)
// ════════════════════════════════════════════════════════════════
describe('handleWebhook', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  // ── Always returns 200 EVENT_RECEIVED ──────────────────────

  it('returns 200 with EVENT_RECEIVED even before processing', async () => {
    const req = { body: { object: 'user' } };

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith('EVENT_RECEIVED');
  });

  it('returns 200 EVENT_RECEIVED for a valid page event body', async () => {
    const req = { body: { object: 'page', entry: [] } };

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.send).toHaveBeenCalledWith('EVENT_RECEIVED');
  });

  // ── Ignores non-page objects ───────────────────────────────

  it('does not call any botService method when body.object is not page', async () => {
    const req = { body: { object: 'user', entry: [{ messaging: [] }] } };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
    expect(botService.handlePostback).not.toHaveBeenCalled();
    expect(botService.handleOptIn).not.toHaveBeenCalled();
  });

  // ── Empty entry array ──────────────────────────────────────

  it('handles an empty entry array gracefully', async () => {
    const req = { body: { object: 'page', entry: [] } };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });

  // ── Skips echo messages ────────────────────────────────────

  it('skips echo messages (message.is_echo === true)', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '111' },
            message: { is_echo: true, text: 'Hello' },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });

  // ── Text messages → handleIncomingMessage ──────────────────

  it('delegates text messages to handleIncomingMessage', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '222' },
            message: { text: 'Bonjour' },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).toHaveBeenCalledWith('222', 'Bonjour');
  });

  it('ignores whitespace-only text messages', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '222' },
            message: { text: '   ' },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });

  it('handles message with empty/missing text gracefully', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '222' },
            message: {},
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });

  // ── quick_reply → handlePostback ───────────────────────────

  it('delegates quick_reply to handlePostback', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '333' },
            message: {
              text: 'Quick reply label',
              quick_reply: { payload: 'QUICK_APPOINTMENT' },
            },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handlePostback).toHaveBeenCalledWith('333', 'QUICK_APPOINTMENT');
    // quick_reply takes priority over plain text — handleIncomingMessage should NOT be called
    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });

  // ── postback → handlePostback ──────────────────────────────

  it('delegates postback events to handlePostback', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '444' },
            postback: { payload: 'GET_STARTED' },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handlePostback).toHaveBeenCalledWith('444', 'GET_STARTED');
  });

  it('ignores postback with falsy payload', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '444' },
            postback: { payload: null },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handlePostback).not.toHaveBeenCalled();
  });

  // ── optin → handleOptIn ────────────────────────────────────

  it('delegates optin events to handleOptIn', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '555' },
            optin: { ref: 'REF_SOURCE_X' },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleOptIn).toHaveBeenCalledWith('555', 'REF_SOURCE_X');
  });

  it('passes empty string as ref when optin.ref is missing', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: { id: '555' },
            optin: {},
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleOptIn).toHaveBeenCalledWith('555', '');
  });

  // ── Skips events without senderId ──────────────────────────

  it('skips messaging events that have no sender.id', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            // sender is undefined
            message: { text: 'Hello' },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });

  it('skips messaging events where sender exists but id is undefined', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [{
            sender: {},
            message: { text: 'Hello' },
          }],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });

  // ── Error handling (catch block) ───────────────────────────

  it('continues processing other events when one event throws', async () => {
    // Make handleIncomingMessage reject for the first call but succeed for the second
    botService.handleIncomingMessage
      .mockRejectedValueOnce(new Error('bot service down'));

    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [
            { sender: { id: 'AAA' }, message: { text: 'First' } },
            { sender: { id: 'BBB' }, message: { text: 'Second' } },
          ],
        }],
      },
    };

    // Should NOT throw
    await handleWebhook(req, res);

    // Both calls were attempted
    expect(botService.handleIncomingMessage).toHaveBeenCalledTimes(2);
    expect(botService.handleIncomingMessage).toHaveBeenNthCalledWith(1, 'AAA', 'First');
    expect(botService.handleIncomingMessage).toHaveBeenNthCalledWith(2, 'BBB', 'Second');
  });

  it('handles errors across multiple entry batches without crashing', async () => {
    botService.handlePostback
      .mockRejectedValueOnce(new Error('postback fail'));

    const req = {
      body: {
        object: 'page',
        entry: [
          {
            messaging: [{
              sender: { id: 'C1' },
              postback: { payload: 'FAIL_PAYLOAD' },
            }],
          },
          {
            messaging: [{
              sender: { id: 'C2' },
              message: { text: 'Safe message' },
            }],
          },
        ],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handlePostback).toHaveBeenCalledWith('C1', 'FAIL_PAYLOAD');
    expect(botService.handleIncomingMessage).toHaveBeenCalledWith('C2', 'Safe message');
  });

  // ── Multiple events in a single entry ──────────────────────

  it('processes all messaging events within a single entry', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{
          messaging: [
            { sender: { id: 'U1' }, message: { text: 'Hi' } },
            { sender: { id: 'U2' }, postback: { payload: 'P1' } },
            { sender: { id: 'U3' }, optin: { ref: 'R1' } },
          ],
        }],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).toHaveBeenCalledWith('U1', 'Hi');
    expect(botService.handlePostback).toHaveBeenCalledWith('U2', 'P1');
    expect(botService.handleOptIn).toHaveBeenCalledWith('U3', 'R1');
  });

  // ── Guard: missing entry or messaging ──────────────────────

  it('handles body with no entry key gracefully', async () => {
    const req = { body: { object: 'page' } };

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });

  it('handles entry with no messaging key gracefully', async () => {
    const req = {
      body: {
        object: 'page',
        entry: [{}],
      },
    };

    await handleWebhook(req, res);

    expect(botService.handleIncomingMessage).not.toHaveBeenCalled();
  });
});
