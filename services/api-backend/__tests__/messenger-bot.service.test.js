/**
 * Messenger Bot Service Tests
 * Tests for conversation state machine, language detection, budget parsing,
 * lead creation, and state transitions.
 */

const mockDb = {
  insert: jest.fn(),
  select: jest.fn(),
};
jest.mock('../src/database/connection', () => ({ db: mockDb }));
jest.mock('../src/database/schema', () => ({
  leadsTable: 'leadsTable',
  buildingsTable: 'buildingsTable',
  unitsTable: 'unitsTable',
  employeesTable: 'employeesTable',
  employeeAssignmentsTable: 'employeeAssignmentsTable',
  employeeSchedulesTable: 'employeeSchedulesTable',
  visitsTable: 'visitsTable',
  communicationLogsTable: 'communicationLogsTable',
}));

const mockFbService = {
  sendTextMessage: jest.fn(),
  sendQuickReplies: jest.fn(),
  sendGenericTemplate: jest.fn(),
  getUserProfile: jest.fn(),
};
jest.mock('../src/services/facebook.service', () => mockFbService);

const mockSmsService = {
  sendSms: jest.fn(),
};
jest.mock('../src/services/sms.service', () => mockSmsService);

const mockLogger = {
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
};
jest.mock('../src/utils/logger', () => mockLogger);

let botService;

beforeEach(() => {
  jest.clearAllMocks();
  jest.resetModules();

  // Setup mock DB chain
  mockDb.insert.mockReturnValue({
    values: jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([{ id: 1 }]),
    }),
  });
  mockDb.select.mockReturnValue({
    from: jest.fn().mockReturnValue({
      innerJoin: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([]),
          orderBy: jest.fn().mockReturnValue({ limit: jest.fn().mockResolvedValue([]) }),
        }),
      }),
    }),
  });

  mockFbService.sendTextMessage.mockResolvedValue({ recipient_id: 'test' });
  mockFbService.sendQuickReplies.mockResolvedValue({ recipient_id: 'test' });
  mockFbService.sendGenericTemplate.mockResolvedValue({ recipient_id: 'test' });
  mockFbService.getUserProfile.mockResolvedValue(null);

  botService = require('../src/services/messenger-bot.service');
});

// ─── detectLanguage ───

describe('detectLanguage', () => {
  it('returns "fr" for French text', () => {
    expect(botService.detectLanguage('Bonjour, je cherche un logement')).toBe('fr');
  });

  it('returns "fr" for empty string', () => {
    expect(botService.detectLanguage('')).toBe('fr');
  });

  it('returns "fr" for null/undefined', () => {
    expect(botService.detectLanguage(null)).toBe('fr');
    expect(botService.detectLanguage(undefined)).toBe('fr');
  });

  it('returns "en" when text has 2+ English marker words', () => {
    expect(botService.detectLanguage('Hello, I am looking for an apartment')).toBe('en');
  });

  it('returns "en" for "yes I want to visit"', () => {
    expect(botService.detectLanguage('yes I want to visit')).toBe('en');
  });

  it('returns "fr" when text has only 1 English marker word', () => {
    expect(botService.detectLanguage('hello comment ça va')).toBe('fr');
  });

  it('returns "en" for "no pets budget 1200"', () => {
    expect(botService.detectLanguage('no pets budget 1200')).toBe('en');
  });

  it('is case-insensitive', () => {
    expect(botService.detectLanguage('HELLO YES I AM')).toBe('en');
  });
});

// ─── createLeadFromConversation ───

describe('createLeadFromConversation', () => {
  it('creates a lead with full data', async () => {
    const mockReturning = jest.fn().mockResolvedValue([{ id: 42, fullName: 'Jean Tremblay' }]);
    const mockValues = jest.fn().mockReturnValue({ returning: mockReturning });
    mockDb.insert.mockReturnValue({ values: mockValues });

    const lead = await botService.createLeadFromConversation('psid_123456', {
      language: 'fr',
      reason: 'travail',
      employment: 'temps plein',
      occupants: 2,
      pets: 'yes',
      budgetCents: 120000,
      buildingId: 'bld-1',
      unitId: 'unit-1',
      firstName: 'Jean',
      lastName: 'Tremblay',
    });

    expect(lead).toEqual({ id: 42, fullName: 'Jean Tremblay' });
    expect(mockDb.insert).toHaveBeenCalledWith('leadsTable');
    const valuesArg = mockValues.mock.calls[0][0];
    expect(valuesArg.fullName).toBe('Jean Tremblay');
    expect(valuesArg.source).toBe('facebook');
    expect(valuesArg.stage).toBe('nouveau');
    expect(valuesArg.tags).toEqual(['travail', 'temps plein', 'pets']);
    expect(valuesArg.notes).toContain('Raison: travail');
    expect(valuesArg.notes).toContain('Budget: $1200/mois');
    expect(valuesArg.notes).toContain('Source: Facebook Messenger');
    expect(valuesArg.notes).toContain('FB PSID: psid_123456');
  });

  it('uses "FB User" fallback name when no name provided', async () => {
    const mockReturning = jest.fn().mockResolvedValue([{ id: 1 }]);
    mockDb.insert.mockReturnValue({ values: jest.fn().mockReturnValue({ returning: mockReturning }) });

    await botService.createLeadFromConversation('psid_abcdef', {
      language: 'en',
    });

    const valuesArg = mockDb.insert.mock.results[0].value.values.mock.calls[0][0];
    expect(valuesArg.fullName).toBe('FB User abcdef');
  });

  it('defaults language to "fr" when not provided', async () => {
    const mockReturning = jest.fn().mockResolvedValue([{ id: 1 }]);
    mockDb.insert.mockReturnValue({ values: jest.fn().mockReturnValue({ returning: mockReturning }) });

    await botService.createLeadFromConversation('psid_123', {});

    const valuesArg = mockDb.insert.mock.results[0].value.values.mock.calls[0][0];
    expect(valuesArg.language).toBe('fr');
  });

  it('excludes pets tag when pets is "no"', async () => {
    const mockReturning = jest.fn().mockResolvedValue([{ id: 1 }]);
    mockDb.insert.mockReturnValue({ values: jest.fn().mockReturnValue({ returning: mockReturning }) });

    await botService.createLeadFromConversation('psid_123', {
      reason: 'déménagement',
      employment: 'étudiant',
      pets: 'no',
    });

    const valuesArg = mockDb.insert.mock.results[0].value.values.mock.calls[0][0];
    expect(valuesArg.tags).toEqual(['déménagement', 'étudiant']);
  });

  it('omits empty notes fields', async () => {
    const mockReturning = jest.fn().mockResolvedValue([{ id: 1 }]);
    mockDb.insert.mockReturnValue({ values: jest.fn().mockReturnValue({ returning: mockReturning }) });

    await botService.createLeadFromConversation('psid_123', {});

    const valuesArg = mockDb.insert.mock.results[0].value.values.mock.calls[0][0];
    expect(valuesArg.notes).not.toContain('Raison:');
    expect(valuesArg.notes).not.toContain('Emploi:');
    expect(valuesArg.notes).toContain('Source: Facebook Messenger');
  });
});

// ─── getAvailableListings ───

describe('getAvailableListings', () => {
  it('queries vacant active units with criteria', async () => {
    const mockResults = [{ unit: { id: 'u1' }, building: { id: 'b1', name: 'Le Château' } }];
    const mockLimit = jest.fn().mockResolvedValue(mockResults);
    const mockWhere = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockInnerJoin = jest.fn().mockReturnValue({ where: mockWhere });
    const mockFrom = jest.fn().mockReturnValue({ innerJoin: mockInnerJoin });
    mockDb.select.mockReturnValue({ from: mockFrom });

    const results = await botService.getAvailableListings({
      budgetCents: 150000,
      occupants: 3,
      buildingId: 'b1',
    });

    expect(results).toEqual(mockResults);
    expect(mockDb.select).toHaveBeenCalled();
  });

  it('returns empty array when no units match', async () => {
    const mockLimit = jest.fn().mockResolvedValue([]);
    const mockWhere = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockInnerJoin = jest.fn().mockReturnValue({ where: mockWhere });
    const mockFrom = jest.fn().mockReturnValue({ innerJoin: mockInnerJoin });
    mockDb.select.mockReturnValue({ from: mockFrom });

    const results = await botService.getAvailableListings({});

    expect(results).toEqual([]);
  });
});

// ─── getVisitSlots ───

describe('getVisitSlots', () => {
  it('queries schedules for a building on a given date', async () => {
    const mockSlots = [
      { employeeId: 'e1', employeeName: 'Simon', startTime: '09:00', endTime: '12:00' },
    ];
    const mockLimit = jest.fn().mockResolvedValue(mockSlots);
    const mockOrderBy = jest.fn().mockReturnValue({ limit: mockLimit });
    const mockWhere = jest.fn().mockReturnValue({ orderBy: mockOrderBy });
    const mockInnerJoin2 = jest.fn().mockReturnValue({ where: mockWhere });
    const mockInnerJoin1 = jest.fn().mockReturnValue({ innerJoin: mockInnerJoin2 });
    const mockFrom = jest.fn().mockReturnValue({ innerJoin: mockInnerJoin1 });
    mockDb.select.mockReturnValue({ from: mockFrom });

    // Monday (dayOfWeek = 0)
    const monday = new Date('2026-04-13');
    const results = await botService.getVisitSlots('bld-1', monday);

    expect(results).toEqual(mockSlots);
  });
});

describe('handleIncomingAttachment', () => {
  it('logs attachment-only Messenger messages with attachment metadata', async () => {
    const mockReturning = jest.fn().mockResolvedValue([{ id: 1 }]);
    const mockValues = jest.fn().mockReturnValue({ returning: mockReturning });
    mockDb.insert.mockReturnValue({ values: mockValues });

    await botService.handleIncomingAttachment('sender-attachment', [
      { type: 'image', payload: { url: 'https://example.com/image.jpg' } },
      { type: 'file', payload: { url: 'https://example.com/file.pdf' } },
    ]);

    expect(mockDb.insert).toHaveBeenCalledWith('communicationLogsTable');
    expect(mockValues).toHaveBeenCalledWith(expect.objectContaining({
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Pièce jointe Messenger reçue (image, file)',
      status: 'received',
      attachments: expect.arrayContaining([
        expect.objectContaining({ type: 'image' }),
        expect.objectContaining({ type: 'file' }),
      ]),
      metadata: {
        attachmentCount: 2,
        attachmentTypes: ['image', 'file'],
      },
    }));
  });
});

// ─── handleIncomingMessage — state transitions ───

describe('handleIncomingMessage — state machine', () => {
  it('sends welcome and quick reply on NEW state', async () => {
    await botService.handleIncomingMessage('sender1', 'hello');

    expect(mockFbService.sendTextMessage).toHaveBeenCalledWith(
      'sender1',
      expect.stringContaining('Bonjour'),
    );
    expect(mockDb.insert).toHaveBeenCalledWith('communicationLogsTable');
  });

  it('transitions from NEW to ASKED_LANGUAGE after welcome', async () => {
    await botService.handleIncomingMessage('sender2', 'hi');
    // Second call — now in ASKED_LANGUAGE state, respond with language choice
    mockFbService.sendQuickReplies.mockClear();
    await botService.handleIncomingMessage('sender2', 'français');

    // Should have moved forward
    expect(mockFbService.sendQuickReplies).toHaveBeenCalled();
  });

  it('handles DONE state with thank you message', async () => {
    // First trigger NEW -> transitions
    await botService.handleIncomingMessage('sender3', 'hello');

    // Force to DONE state by repeated messages through state machine
    // We'll just test the module's exported handleIncomingMessage flow
    // Send enough messages to walk through states
    await botService.handleIncomingMessage('sender3', 'français');
    await botService.handleIncomingMessage('sender3', 'travail');
    await botService.handleIncomingMessage('sender3', 'temps plein');
    await botService.handleIncomingMessage('sender3', '2');
    await botService.handleIncomingMessage('sender3', 'non');
    await botService.handleIncomingMessage('sender3', '1200');

    // Now in ASKED_BUILDING — handleBuilding queries DB which returns []
    // This sends noListings message and sets state to DONE
    await botService.handleIncomingMessage('sender3', 'n\'importe');

    // Now in DONE state
    mockFbService.sendTextMessage.mockClear();
    await botService.handleIncomingMessage('sender3', 'merci');

    expect(mockFbService.sendTextMessage).toHaveBeenCalledWith(
      'sender3',
      expect.stringContaining('ImmoGestion'),
    );
  });

  it('handles errors gracefully', async () => {
    mockFbService.sendTextMessage.mockRejectedValueOnce(new Error('API down'));

    await botService.handleIncomingMessage('sender_err', 'test');

    // Should have caught error and tried to send error message
    expect(mockLogger.error).toHaveBeenCalled();
  });
});

// ─── handlePostback ───

describe('handlePostback', () => {
  it('handles LANG_FR postback by delegating to handleIncomingMessage', async () => {
    await botService.handlePostback('sender_pb', 'LANG_FR');

    expect(mockFbService.sendTextMessage).toHaveBeenCalledWith(
      'sender_pb',
      expect.any(String),
    );
  });

  it('handles REASON_WORK postback with mapped reason', async () => {
    // First set language to 'fr' and advance state
    await botService.handleIncomingMessage('sender_reason', 'hello');
    await botService.handleIncomingMessage('sender_reason', 'français');
    // Now in ASKED_REASON
    mockFbService.sendTextMessage.mockClear();
    mockFbService.sendQuickReplies.mockClear();

    await botService.handlePostback('sender_reason', 'REASON_WORK');

    expect(mockFbService.sendQuickReplies).toHaveBeenCalled();
  });
});

// ─── handleOptIn ───

describe('handleOptIn', () => {
  it('handles opt-in event', async () => {
    await botService.handleOptIn('sender_opt', 'optin');

    expect(mockFbService.sendTextMessage).toHaveBeenCalledWith(
      'sender_opt',
      expect.any(String),
    );
  });
});
