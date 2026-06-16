const { handleWebhook } = require('../src/controllers/plexflow-webhook.controller');
const { safeSecretEqual } = require('../src/utils/webhookAuth');

// ─── Mocks ────────────────────────────────────────────────────────────────────
jest.mock('../src/services/plexflow-webhook.service', () => ({
  processWebhook: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  child: jest.fn(() => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  })),
}));

// ─── Helpers ──────────────────────────────────────────────────────────────────
const plexflowWebhookService = require('../src/services/plexflow-webhook.service');

const mockRes = () => {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
};

const VALID_SECRET = 'pf_test_secret_abc123';
const VALID_PAYLOAD = {
  event: 'lease.updated',
  data: { leaseId: 'l1', unitId: 'u1', rentCents: 120000 },
};

beforeEach(() => {
  jest.clearAllMocks();
  // Set the webhook secret for tests
  process.env.PLEXFLOW_WEBHOOK_SECRET = VALID_SECRET;
  delete process.env.PLEXFLOW_API_KEY;
});

afterEach(() => {
  delete process.env.PLEXFLOW_WEBHOOK_SECRET;
  delete process.env.PLEXFLOW_API_KEY;
});

// ═══════════════════════════════════════════════════════════════════════════════
// safeSecretEqual — unit tests
// ═══════════════════════════════════════════════════════════════════════════════
describe('safeSecretEqual', () => {
  it('returns true for identical strings', () => {
    expect(safeSecretEqual('abc', 'abc')).toBe(true);
  });

  it('returns false for different strings', () => {
    expect(safeSecretEqual('abc', 'def')).toBe(false);
  });

  it('returns false when provided is null', () => {
    expect(safeSecretEqual(null, 'abc')).toBe(false);
  });

  it('returns false when expected is null', () => {
    expect(safeSecretEqual('abc', null)).toBe(false);
  });

  it('returns false when provided is not a string', () => {
    expect(safeSecretEqual(123, 'abc')).toBe(false);
  });

  it('returns false when expected is not a string', () => {
    expect(safeSecretEqual('abc', 456)).toBe(false);
  });

  it('returns false when provided is empty string', () => {
    expect(safeSecretEqual('', 'abc')).toBe(false);
  });

  it('returns false when expected is empty string', () => {
    expect(safeSecretEqual('abc', '')).toBe(false);
  });

  it('returns false for different-length strings (no timing leak)', () => {
    expect(safeSecretEqual('short', 'verylongstring')).toBe(false);
  });

  it('returns false for same-length but different strings', () => {
    expect(safeSecretEqual('abcd', 'abce')).toBe(false);
  });

  it('is case-sensitive', () => {
    expect(safeSecretEqual('ABC', 'abc')).toBe(false);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// handleWebhook — integration tests
// ═══════════════════════════════════════════════════════════════════════════════
describe('handleWebhook', () => {
  // ── Auth: missing secret ────────────────────────────────────────────────────
  it('returns 401 when no PLEXFLOW_WEBHOOK_SECRET is configured', async () => {
    delete process.env.PLEXFLOW_WEBHOOK_SECRET;
    const req = {
      body: VALID_PAYLOAD,
      get: jest.fn().mockReturnValue(VALID_SECRET),
    };
    const res = mockRes();

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PLEXFLOW_WEBHOOK_UNAUTHORIZED' }),
      }),
    );
    expect(plexflowWebhookService.processWebhook).not.toHaveBeenCalled();
  });

  // ── Auth: missing header ────────────────────────────────────────────────────
  it('returns 401 when X-Plexflow-Key header is missing', async () => {
    const req = {
      body: VALID_PAYLOAD,
      get: jest.fn().mockReturnValue(undefined),
    };
    const res = mockRes();

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PLEXFLOW_WEBHOOK_UNAUTHORIZED' }),
      }),
    );
    expect(plexflowWebhookService.processWebhook).not.toHaveBeenCalled();
  });

  // ── Auth: invalid signature ─────────────────────────────────────────────────
  it('returns 401 when X-Plexflow-Key does not match secret', async () => {
    const req = {
      body: VALID_PAYLOAD,
      get: jest.fn().mockReturnValue('wrong_secret'),
    };
    const res = mockRes();

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PLEXFLOW_WEBHOOK_UNAUTHORIZED' }),
      }),
    );
    expect(plexflowWebhookService.processWebhook).not.toHaveBeenCalled();
  });

  // ── Auth: empty header ──────────────────────────────────────────────────────
  it('returns 401 when X-Plexflow-Key is empty string', async () => {
    const req = {
      body: VALID_PAYLOAD,
      get: jest.fn().mockReturnValue(''),
    };
    const res = mockRes();

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(plexflowWebhookService.processWebhook).not.toHaveBeenCalled();
  });

  // ── Auth: falls back to PLEXFLOW_API_KEY ────────────────────────────────────
  it('uses PLEXFLOW_API_KEY when PLEXFLOW_WEBHOOK_SECRET is not set', async () => {
    delete process.env.PLEXFLOW_WEBHOOK_SECRET;
    process.env.PLEXFLOW_API_KEY = VALID_SECRET;
    const req = {
      body: VALID_PAYLOAD,
      get: jest.fn().mockReturnValue(VALID_SECRET),
    };
    const res = mockRes();
    plexflowWebhookService.processWebhook.mockResolvedValue({ ingested: 1 });

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(plexflowWebhookService.processWebhook).toHaveBeenCalled();
  });

  // ── Auth: lowercase header ──────────────────────────────────────────────────
  it('accepts lowercase x-plexflow-key header', async () => {
    const req = {
      body: VALID_PAYLOAD,
      get: jest.fn((name) => {
        if (name === 'X-Plexflow-Key') return undefined;
        if (name === 'x-plexflow-key') return VALID_SECRET;
        return undefined;
      }),
    };
    const res = mockRes();
    plexflowWebhookService.processWebhook.mockResolvedValue({ ingested: 1 });

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(plexflowWebhookService.processWebhook).toHaveBeenCalled();
  });

  // ── Successful processing ───────────────────────────────────────────────────
  it('returns 200 with result when webhook is valid and processing succeeds', async () => {
    const req = {
      body: VALID_PAYLOAD,
      get: jest.fn().mockReturnValue(VALID_SECRET),
    };
    const res = mockRes();
    plexflowWebhookService.processWebhook.mockResolvedValue({ ingested: 1, unitId: 'u1' });

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { ingested: 1, unitId: 'u1' },
    });
    expect(plexflowWebhookService.processWebhook).toHaveBeenCalledWith(VALID_PAYLOAD);
  });

  // ── Processing failure (ack with 200 to avoid retry storms) ─────────────────
  it('returns 200 with error when processing throws', async () => {
    const req = {
      body: VALID_PAYLOAD,
      get: jest.fn().mockReturnValue(VALID_SECRET),
    };
    const res = mockRes();
    plexflowWebhookService.processWebhook.mockRejectedValue(new Error('DB timeout'));

    await handleWebhook(req, res);

    // Must still return 200 to avoid PlexFlow retry storms
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PLEXFLOW_WEBHOOK_FAILED' }),
      }),
    );
  });

  // ── Empty body ──────────────────────────────────────────────────────────────
  it('handles empty body gracefully', async () => {
    const req = {
      body: {},
      get: jest.fn().mockReturnValue(VALID_SECRET),
    };
    const res = mockRes();
    plexflowWebhookService.processWebhook.mockResolvedValue({ ingested: 0 });

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(plexflowWebhookService.processWebhook).toHaveBeenCalledWith({});
  });

  // ── Various event types ─────────────────────────────────────────────────────
  const eventTypes = [
    { event: 'lease.created', data: { leaseId: 'l1' } },
    { event: 'lease.updated', data: { leaseId: 'l2' } },
    { event: 'lease.terminated', data: { leaseId: 'l3' } },
    { event: 'tenant.moved_in', data: { unitId: 'u1' } },
    { event: 'tenant.moved_out', data: { unitId: 'u2' } },
    { event: 'unit.vacant', data: { unitId: 'u3' } },
    { event: 'unit.occupied', data: { unitId: 'u4' } },
  ];

  it.each(eventTypes)(
    'accepts event type "$event"',
    async ({ event, data }) => {
      const req = {
        body: { event, data },
        get: jest.fn().mockReturnValue(VALID_SECRET),
      };
      const res = mockRes();
      plexflowWebhookService.processWebhook.mockResolvedValue({ ingested: 1 });

      await handleWebhook(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(plexflowWebhookService.processWebhook).toHaveBeenCalledWith({ event, data });
    },
  );

  // ── Alternative event field names ───────────────────────────────────────────
  it('accepts eventType as alternative to event', async () => {
    const req = {
      body: { eventType: 'lease.updated', data: {} },
      get: jest.fn().mockReturnValue(VALID_SECRET),
    };
    const res = mockRes();
    plexflowWebhookService.processWebhook.mockResolvedValue({ ingested: 1 });

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(plexflowWebhookService.processWebhook).toHaveBeenCalled();
  });

  it('accepts type as alternative to event', async () => {
    const req = {
      body: { type: 'lease.updated', data: {} },
      get: jest.fn().mockReturnValue(VALID_SECRET),
    };
    const res = mockRes();
    plexflowWebhookService.processWebhook.mockResolvedValue({ ingested: 1 });

    await handleWebhook(req, res);

    expect(res.status).toHaveBeenCalledWith(200);
    expect(plexflowWebhookService.processWebhook).toHaveBeenCalled();
  });
});
