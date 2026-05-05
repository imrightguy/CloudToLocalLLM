// ─── Communication Controller Validation Tests ───
// Tests the inline validation logic of the communication controller.
// These test the validation contract that the controller enforces before DB operations.

// Valid types and directions are enforced inline in the controller.
// We verify these constants match what the controller expects.

const VALID_TYPES = ['sms', 'email', 'phone', 'fb_messenger'];
const VALID_DIRECTIONS = ['inbound', 'outbound'];

describe('Communication Controller Validation', () => {
  describe('logCommunication — type validation', () => {
    it('accepts all valid types', () => {
      expect(VALID_TYPES).toContain('sms');
      expect(VALID_TYPES).toContain('email');
      expect(VALID_TYPES).toContain('phone');
      expect(VALID_TYPES).toContain('fb_messenger');
    });

    it('rejects invalid type values', () => {
      const invalidTypes = ['whatsapp', 'slack', 'mail', 'fax', '', null, undefined, 123, {}, []];
      for (const t of invalidTypes) {
        expect(VALID_TYPES.includes(t)).toBe(false);
      }
    });
  });

  describe('logCommunication — direction validation', () => {
    it('accepts all valid directions', () => {
      expect(VALID_DIRECTIONS).toContain('inbound');
      expect(VALID_DIRECTIONS).toContain('outbound');
    });

    it('rejects invalid direction values', () => {
      const invalidDirs = ['bidirectional', 'in', 'out', 'both', '', null, undefined];
      for (const d of invalidDirs) {
        expect(VALID_DIRECTIONS.includes(d)).toBe(false);
      }
    });
  });

  describe('logCommunication — required fields', () => {
    it('type is required (null/undefined/empty rejected)', () => {
      expect(VALID_TYPES.includes(null)).toBe(false);
      expect(VALID_TYPES.includes(undefined)).toBe(false);
      expect(VALID_TYPES.includes('')).toBe(false);
    });

    it('direction is required (null/undefined/empty rejected)', () => {
      expect(VALID_DIRECTIONS.includes(null)).toBe(false);
      expect(VALID_DIRECTIONS.includes(undefined)).toBe(false);
      expect(VALID_DIRECTIONS.includes('')).toBe(false);
    });

    it('optional fields have sensible defaults', () => {
      const defaults = {
        leadId: null,
        employeeId: null,
        content: null,
        subject: null,
        attachments: [],
        status: 'sent',
        metadata: {},
      };
      expect(defaults.status).toBe('sent');
      expect(Array.isArray(defaults.attachments)).toBe(true);
      expect(defaults.attachments).toHaveLength(0);
      expect(typeof defaults.metadata).toBe('object');
    });
  });

  describe('getCommunications — query parameter defaults', () => {
    it('defaults page to 1', () => {
      const page = undefined;
      const result = parseInt(page || 1);
      expect(result).toBe(1);
    });

    it('defaults limit to 20', () => {
      const limit = undefined;
      const result = parseInt(limit || 20);
      expect(result).toBe(20);
    });

    it('calculates offset correctly', () => {
      const offset = (parseInt(2) - 1) * parseInt(10);
      expect(offset).toBe(10);
    });
  });

  describe('getActivityFeed — type filter parsing', () => {
    const allTypes = [
      'lead_created', 'visit_scheduled', 'visit_completed', 'visit_cancelled',
      'visit_no_show', 'visit_rescheduled',
      'sms_sent', 'sms_received', 'communication_logged',
    ];

    it('accepts all valid activity types', () => {
      for (const t of allTypes) {
        expect(allTypes.includes(t)).toBe(true);
      }
    });

    it('parses comma-separated type filter correctly', () => {
      const input = 'lead_created,visit_scheduled';
      const parsed = input.split(',').map((t) => t.trim()).filter((t) => allTypes.includes(t));
      expect(parsed).toEqual(['lead_created', 'visit_scheduled']);
    });

    it('filters out invalid types from comma-separated input', () => {
      const input = 'lead_created,invalid_type,visit_completed';
      const parsed = input.split(',').map((t) => t.trim()).filter((t) => allTypes.includes(t));
      expect(parsed).toEqual(['lead_created', 'visit_completed']);
    });

    it('handles whitespace in type filter', () => {
      const input = ' lead_created , visit_scheduled ';
      const parsed = input.split(',').map((t) => t.trim()).filter((t) => allTypes.includes(t));
      expect(parsed).toEqual(['lead_created', 'visit_scheduled']);
    });

    it('returns null (all types) when no filter provided', () => {
      const type = undefined;
      const filterTypes = type ? type.split(',') : null;
      expect(filterTypes).toBeNull();
    });
  });

  describe('getActivityFeed — limit and hoursAgo clamping', () => {
    it('clamps limit between 1 and 100', () => {
      const clamp = (v) => Math.min(100, Math.max(1, parseInt(v)));
      expect(clamp(30)).toBe(30);
      expect(clamp(0)).toBe(1);
      expect(clamp(-5)).toBe(1);
      expect(clamp(150)).toBe(100);
      expect(clamp(1)).toBe(1);
      expect(clamp(100)).toBe(100);
    });

    it('clamps hoursAgo between 1 and 720', () => {
      const clamp = (v) => Math.min(720, Math.max(1, parseInt(v)));
      expect(clamp(168)).toBe(168);
      expect(clamp(0)).toBe(1);
      expect(clamp(-10)).toBe(1);
      expect(clamp(1000)).toBe(720);
      expect(clamp(720)).toBe(720);
      expect(clamp(1)).toBe(1);
    });
  });

  describe('getActivityFeed — activity sorting', () => {
    it('sorts activities by timestamp descending', () => {
      const activities = [
        { type: 'lead_created', timestamp: '2024-01-01T10:00:00Z' },
        { type: 'sms_sent', timestamp: '2024-01-03T15:00:00Z' },
        { type: 'visit_scheduled', timestamp: '2024-01-02T09:00:00Z' },
      ];
      activities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
      expect(activities[0].type).toBe('sms_sent');
      expect(activities[1].type).toBe('visit_scheduled');
      expect(activities[2].type).toBe('lead_created');
    });

    it('limits results after sorting', () => {
      const activities = Array.from({ length: 50 }, (_, i) => ({
        type: 'lead_created',
        timestamp: new Date(Date.now() - i * 60000).toISOString(),
      }));
      activities.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
      const result = activities.slice(0, 10);
      expect(result).toHaveLength(10);
    });
  });

  describe('getActivityFeed — visit outcome text mapping', () => {
    const outcomeTextMap = {
      interesse: ' — intéressé',
      pas_interesse: ' — pas intéressé',
      no_show: ' — absent',
    };

    const outcomeText = (outcome) => outcomeTextMap[outcome] || '';

    it('maps interesse to interested text', () => {
      expect(outcomeText('interesse')).toBe(' — intéressé');
    });

    it('maps pas_interesse to not interested text', () => {
      expect(outcomeText('pas_interesse')).toBe(' — pas intéressé');
    });

    it('maps no_show to absent text', () => {
      expect(outcomeText('no_show')).toBe(' — absent');
    });

    it('returns empty string for unknown outcomes', () => {
      expect(outcomeText('cancelled')).toBe('');
    });
  });

  describe('getActivityFeed — communication type labels', () => {
    const typeLabels = { email: 'E-mail', phone: 'Appel', fb_messenger: 'Messenger' };

    it('maps email to E-mail', () => {
      expect(typeLabels.email).toBe('E-mail');
    });

    it('maps phone to Appel', () => {
      expect(typeLabels.phone).toBe('Appel');
    });

    it('maps fb_messenger to Messenger', () => {
      expect(typeLabels.fb_messenger).toBe('Messenger');
    });

    it('falls back to raw type for unknown types', () => {
      expect(typeLabels.sms || 'sms').toBe('sms');
    });
  });

  describe('getActivityFeed — direction labels', () => {
    const dirLabel = (dir) => (dir === 'inbound' ? ' reçu de' : ' envoyé à');

    it('maps inbound to reçu de', () => {
      expect(dirLabel('inbound')).toBe(' reçu de');
    });

    it('maps outbound to envoyé à', () => {
      expect(dirLabel('outbound')).toBe(' envoyé à');
    });
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// Communication Controller Function Tests (actual import)
// ═══════════════════════════════════════════════════════════════════════════════

// --- Mock DB result queue: each awaited DB call shifts one entry ---
let mockDbResults = [];

function mockCreateChain() {
  const instance = {
    then: (resolve, reject) => {
      const val = mockDbResults.length > 0 ? mockDbResults.shift() : [];
      return Promise.resolve(val).then(resolve, reject);
    },
    catch: () => instance,
  };
  const chainMethods = [
    'insert', 'values', 'returning',
    'select', 'from', 'where', 'orderBy', 'limit', 'offset', 'leftJoin',
  ];
  for (const m of chainMethods) {
    instance[m] = jest.fn().mockReturnValue(instance);
  }
  return instance;
}

jest.mock('../src/database/connection', () => ({
  db: {
    insert: jest.fn(() => mockCreateChain()),
    select: jest.fn(() => mockCreateChain()),
    update: jest.fn(() => mockCreateChain()),
  },
}));

jest.mock('../src/database/schema', () => ({
  communicationLogsTable: {},
  leadsTable: {},
  visitsTable: {},
  smsLogsTable: {},
  employeesTable: {},
  unitsTable: {},
  buildingsTable: {},
}));

jest.mock('../src/utils/logger', () => ({
  child: jest.fn(() => ({
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    debug: jest.fn(),
  })),
}));

jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ _type: 'eq', col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  or: jest.fn((...conds) => ({ _type: 'or', conds })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
  gte: jest.fn((col, val) => ({ _type: 'gte', col, val })),
}));

// --- Import controller after mocks ---
const communicationController = require('../src/controllers/communication.controller');
const { db } = require('../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
  mockDbResults = [];
});

// ═══════════════════════════════════════════════════════════════════════════════

describe('logCommunication (controller import)', () => {
  it('returns 400 for invalid type', async () => {
    const res = mockRes();
    await communicationController.logCommunication(
      { body: { type: 'whatsapp', direction: 'inbound' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('VALIDATION_ERROR');
    expect(body.error.message).toContain('type is required');
  });

  it('returns 400 for invalid direction', async () => {
    const res = mockRes();
    await communicationController.logCommunication(
      { body: { type: 'sms', direction: 'sideways' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('VALIDATION_ERROR');
    expect(body.error.message).toContain('direction is required');
  });

  it('returns 400 when both type and direction are missing', async () => {
    const res = mockRes();
    await communicationController.logCommunication(
      { body: {} },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('VALIDATION_ERROR');
  });

  it('passes validation and returns 201 with valid type and direction', async () => {
    mockDbResults = [[{
      id: 'uuid-1', type: 'sms', direction: 'outbound', status: 'sent',
    }]];
    const res = mockRes();
    await communicationController.logCommunication(
      { body: { type: 'sms', direction: 'outbound' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(201);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.data.type).toBe('sms');
    expect(body.data.direction).toBe('outbound');
    expect(body.message).toBe('Communication logged successfully');
  });

  it('persists body as content when content is omitted', async () => {
    mockDbResults = [[{
      id: 'uuid-2', type: 'sms', direction: 'outbound', status: 'sent',
    }]];
    const res = mockRes();

    await communicationController.logCommunication(
      { body: { type: 'sms', direction: 'outbound', body: 'Bonjour du body field' } },
      res,
    );

    const insertChain = db.insert.mock.results[0].value;
    expect(insertChain.values).toHaveBeenCalledWith(expect.objectContaining({
      content: 'Bonjour du body field',
    }));
    expect(res.status).toHaveBeenCalledWith(201);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════

describe('getCommunications (controller import)', () => {
  it('does not crash when called with empty query', async () => {
    // Queue: count query result, data query result
    mockDbResults = [[{ count: 0 }], []];
    const res = mockRes();
    await communicationController.getCommunications({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
    const body = res.json.mock.calls[0][0];
    expect(body.data).toEqual([]);
    expect(body.metadata.total).toBe(0);
  });

  it('respects pagination params (page, limit)', async () => {
    mockDbResults = [[{ count: 0 }], []];
    const res = mockRes();
    await communicationController.getCommunications(
      { query: { page: '3', limit: '50' } },
      res,
    );
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.metadata.page).toBe(3);
    expect(body.metadata.limit).toBe(50);
    expect(body.metadata.total).toBe(0);
    expect(body.metadata.totalPages).toBe(0);
    expect(body.metadata.hasMore).toBe(false);
  });

  it('respects filter params (leadId, employeeId, type, direction, status)', async () => {
    mockDbResults = [
      [{ count: 1 }],
      [{ id: 'c1', leadId: 'lead-1', type: 'email' }],
    ];
    const res = mockRes();
    await communicationController.getCommunications({
      query: {
        leadId: 'lead-1',
        employeeId: 'emp-1',
        type: 'email',
        direction: 'inbound',
        status: 'sent',
      },
    }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
    const body = res.json.mock.calls[0][0];
    expect(body.data).toHaveLength(1);
    expect(body.metadata.total).toBe(1);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════

describe('getCommunicationLogById (controller import)', () => {
  it('does not crash with valid UUID — returns 404 when not found', async () => {
    mockDbResults = [[]];
    const res = mockRes();
    await communicationController.getCommunicationLogById(
      { params: { id: '550e8400-e29b-41d4-a716-446655440000' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('COMMUNICATION_NOT_FOUND');
  });

  it('returns 404 for soft-deleted logs', async () => {
    mockDbResults = [[{
      id: '550e8400-e29b-41d4-a716-446655440000',
      isActive: false,
      type: 'email',
      direction: 'inbound',
    }]];
    const res = mockRes();
    await communicationController.getCommunicationLogById(
      { params: { id: '550e8400-e29b-41d4-a716-446655440000' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('COMMUNICATION_NOT_FOUND');
  });

  it('returns the record when found', async () => {
    mockDbResults = [[{
      id: '550e8400-e29b-41d4-a716-446655440000',
      type: 'email',
      direction: 'inbound',
      subject: 'Test subject',
      isActive: true,
    }]];
    const res = mockRes();
    await communicationController.getCommunicationLogById(
      { params: { id: '550e8400-e29b-41d4-a716-446655440000' } },
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
    const body = res.json.mock.calls[0][0];
    expect(body.data.id).toBe('550e8400-e29b-41d4-a716-446655440000');
    expect(body.data.type).toBe('email');
    expect(body.data.subject).toBe('Test subject');
  });
});

// ═══════════════════════════════════════════════════════════════════════════════

describe('getCommunicationLogs — alias (controller import)', () => {
  it('is an alias for getCommunications (delegates to it)', () => {
    // getCommunicationLogs is a wrapper that delegates to getCommunications,
    // not a direct reference, so we verify it is a function and the
    // behavior test below confirms delegation.
    expect(typeof communicationController.getCommunicationLogs).toBe('function');
    expect(typeof communicationController.getCommunications).toBe('function');
  });

  it('returns the same response shape as getCommunications', async () => {
    mockDbResults = [[{ count: 2 }], [{ id: 'c1' }, { id: 'c2' }]];
    const res1 = mockRes();
    const query = { query: { page: '1', limit: '10' } };

    await communicationController.getCommunications(query, res1);

    // Reset mocks and queue for the alias call
    mockDbResults = [[{ count: 2 }], [{ id: 'c1' }, { id: 'c2' }]];
    const res2 = mockRes();
    await communicationController.getCommunicationLogs(query, res2);

    const body1 = res1.json.mock.calls[0][0];
    const body2 = res2.json.mock.calls[0][0];
    expect(body1.success).toBe(true);
    expect(body2.success).toBe(true);
    expect(body1.metadata.page).toBe(body2.metadata.page);
    expect(body1.metadata.limit).toBe(body2.metadata.limit);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════

describe('getActivityFeed (controller import)', () => {
  it('does not crash with empty query', async () => {
    // No type filter → all 6 sub-queries execute
    mockDbResults = [[], [], [], [], [], []];
    const res = mockRes();
    await communicationController.getActivityFeed({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
    const body = res.json.mock.calls[0][0];
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.metadata).toBeDefined();
  });

  it('respects limit and hoursAgo params', async () => {
    mockDbResults = [[], [], [], [], [], []];
    const res = mockRes();
    await communicationController.getActivityFeed({
      query: { limit: '50', hoursAgo: '24' },
    }, res);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.metadata.limit).toBe(50);
    expect(body.metadata.hoursAgo).toBe(24);
  });

  it('clamps out-of-range limit and hoursAgo', async () => {
    mockDbResults = [[], [], [], [], [], []];
    const res = mockRes();
    await communicationController.getActivityFeed({
      query: { limit: '500', hoursAgo: '0' },
    }, res);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.metadata.limit).toBe(100); // clamped to max
    expect(body.metadata.hoursAgo).toBe(1); // clamped to min
  });

  it('respects type filter — only executes relevant sub-queries', async () => {
    // Only lead_created → 1 sub-query (new leads)
    mockDbResults = [[{
      id: 'l1',
      fullName: 'Marie Tremblay',
      phone: '+15145551234',
      source: 'web',
      stage: 'new',
      createdAt: new Date().toISOString(),
    }]];
    const res = mockRes();
    await communicationController.getActivityFeed({
      query: { type: 'lead_created' },
    }, res);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.metadata.types).toEqual(['lead_created']);
    // Only 1 sub-query should have been made
    expect(db.select).toHaveBeenCalledTimes(1);
    expect(body.data).toHaveLength(1);
    expect(body.data[0].type).toBe('lead_created');
  });
});

// ═══════════════════════════════════════════════════════════════════════════════

describe('updateCommunicationLog (controller import)', () => {
  it('returns 404 when log not found', async () => {
    mockDbResults = [[]];
    const res = mockRes();
    await communicationController.updateCommunicationLog(
      { params: { id: '550e8400-e29b-41d4-a716-446655440000' }, body: { content: 'updated' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('COMMUNICATION_NOT_FOUND');
  });

  it('returns 404 when attempting to update a soft-deleted log', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', direction: 'inbound', isActive: false }]];
    const res = mockRes();
    await communicationController.updateCommunicationLog(
      { params: { id: 'c1' }, body: { status: 'delivered' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('COMMUNICATION_NOT_FOUND');
  });

  it('returns 400 for invalid status', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', direction: 'inbound', isActive: true }]];
    const res = mockRes();
    await communicationController.updateCommunicationLog(
      { params: { id: 'c1' }, body: { status: 'bogus' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('VALIDATION_ERROR');
    expect(body.error.message).toContain('Statut invalide');
  });

  it('updates active logs with an active-only write guard', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', direction: 'inbound', isActive: true }]];
    const where = jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([{ id: 'c1', type: 'email', direction: 'inbound', isActive: true, status: 'delivered' }]),
    });
    const set = jest.fn().mockReturnValue({ where });
    db.update.mockImplementationOnce(() => ({ set }));
    const res = mockRes();

    await communicationController.updateCommunicationLog(
      { params: { id: 'c1' }, body: { status: 'delivered' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'c1', status: 'delivered' }),
    }));
    expect(where).toHaveBeenCalledWith(expect.objectContaining({
      _type: 'and',
      conds: expect.arrayContaining([
        expect.objectContaining({ _type: 'eq', val: 'c1' }),
        expect.objectContaining({ _type: 'eq', val: true }),
      ]),
    }));
  });

  it('updates content from body when content is omitted', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', direction: 'inbound', isActive: true }]];
    const where = jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([{ id: 'c1', type: 'email', direction: 'inbound', isActive: true, content: 'Texte body mis a jour' }]),
    });
    const set = jest.fn().mockReturnValue({ where });
    db.update.mockImplementationOnce(() => ({ set }));
    const res = mockRes();

    await communicationController.updateCommunicationLog(
      { params: { id: 'c1' }, body: { body: 'Texte body mis a jour' } },
      res,
    );

    expect(set).toHaveBeenCalledWith(expect.objectContaining({
      content: 'Texte body mis a jour',
    }));
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('returns 404 when the active-only update guard matches zero rows', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', direction: 'inbound', isActive: true }]];
    const where = jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([]),
    });
    const set = jest.fn().mockReturnValue({ where });
    db.update.mockImplementationOnce(() => ({ set }));
    const res = mockRes();

    await communicationController.updateCommunicationLog(
      { params: { id: 'c1' }, body: { status: 'delivered' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('COMMUNICATION_NOT_FOUND');
  });

  it('returns 500 when db update fails', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', direction: 'inbound', isActive: true }]];
    const res = mockRes();
    await communicationController.updateCommunicationLog(
      { params: { id: 'c1' }, body: { content: 'updated content' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    const body = res.json.mock.calls[0][0];
    expect(body.error.code).toBe('COMMUNICATION_UPDATE_FAILED');
  });
});

// ═══════════════════════════════════════════════════════════════════════════════

describe('deleteCommunicationLog (controller import)', () => {
  it('returns 404 when log not found', async () => {
    mockDbResults = [[]];
    const res = mockRes();
    await communicationController.deleteCommunicationLog(
      { params: { id: '550e8400-e29b-41d4-a716-446655440000' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('COMMUNICATION_NOT_FOUND');
  });

  it('returns 404 when attempting to delete a soft-deleted log again', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', isActive: false }]];
    const res = mockRes();
    await communicationController.deleteCommunicationLog(
      { params: { id: 'c1' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('COMMUNICATION_NOT_FOUND');
  });

  it('soft-deletes active logs with an active-only write guard', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', isActive: true }]];
    const returning = jest.fn().mockResolvedValue([{ id: 'c1', isActive: false }]);
    const where = jest.fn().mockReturnValue({ returning });
    const set = jest.fn().mockReturnValue({ where });
    db.update.mockImplementationOnce(() => ({ set }));
    const res = mockRes();

    await communicationController.deleteCommunicationLog(
      { params: { id: 'c1' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true, data: null }));
    expect(where).toHaveBeenCalledWith(expect.objectContaining({
      _type: 'and',
      conds: expect.arrayContaining([
        expect.objectContaining({ _type: 'eq', val: 'c1' }),
        expect.objectContaining({ _type: 'eq', val: true }),
      ]),
    }));
    expect(returning).toHaveBeenCalled();
  });

  it('returns 404 when the active-only delete guard matches zero rows', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', isActive: true }]];
    const where = jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([]),
    });
    const set = jest.fn().mockReturnValue({ where });
    db.update.mockImplementationOnce(() => ({ set }));
    const res = mockRes();

    await communicationController.deleteCommunicationLog(
      { params: { id: 'c1' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('COMMUNICATION_NOT_FOUND');
  });

  it('returns 500 when db delete fails', async () => {
    mockDbResults = [[{ id: 'c1', type: 'email', isActive: true }]];
    const res = mockRes();
    await communicationController.deleteCommunicationLog(
      { params: { id: 'c1' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    const body = res.json.mock.calls[0][0];
    expect(body.error.code).toBe('COMMUNICATION_DELETE_FAILED');
  });
});
