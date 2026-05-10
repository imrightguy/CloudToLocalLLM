/**
 * Messenger Bot Service Tests
 * Tests for conversation state machine, language detection, budget parsing,
 * lead creation, and state transitions.
 */

const mockDb = {
  insert: jest.fn(),
  select: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
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
  messengerConversationsTable: 'messengerConversationsTable',
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
  sendVisitConfirmation: jest.fn(),
  sendTenantConfirmationRequest: jest.fn(),
  sendOccupantAccessRequest: jest.fn(),
  sendLeadFollowUpSms: jest.fn(),
};
jest.mock('../src/services/sms.service', () => mockSmsService);

const mockCommunicationThreadService = {
  refreshCommunicationThread: jest.fn().mockResolvedValue(null),
};
jest.mock('../src/services/communication-thread.service', () => mockCommunicationThreadService);

jest.mock('../src/controllers/tenant-confirmation.controller', () => ({
  generateConfirmationToken: jest.fn(() => 'token-abc'),
}));

const mockCheckVisitConflict = jest.fn();
const mockCheckScheduleAvailability = jest.fn();

jest.mock('../src/controllers/visit.controller', () => ({
  checkVisitConflict: (...args) => mockCheckVisitConflict(...args),
  checkScheduleAvailability: (...args) => mockCheckScheduleAvailability(...args),
}));

const mockLogger = {
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
};
jest.mock('../src/utils/logger', () => mockLogger);

let botService;

const mockMessengerConversationSelect = () => ({
  from: jest.fn().mockReturnValue({
    where: jest.fn().mockReturnValue({
      limit: jest.fn().mockResolvedValue([]),
    }),
  }),
});

function getLeadUpdatePayloads() {
  return mockDb.update.mock.calls
    .map(([table], index) => (table === 'leadsTable'
      ? mockDb.update.mock.results[index].value.set.mock.calls[0][0]
      : null))
    .filter(Boolean);
}

beforeEach(() => {
  jest.clearAllMocks();
  jest.resetModules();

  // Setup mock DB chain
  mockDb.insert.mockImplementation(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([{ id: 1 }]),
      onConflictDoUpdate: jest.fn().mockResolvedValue([]),
    }),
  }));
  mockDb.select.mockReturnValue({
    from: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        limit: jest.fn().mockResolvedValue([]),
        orderBy: jest.fn().mockReturnValue({ limit: jest.fn().mockResolvedValue([]) }),
      }),
      innerJoin: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([]),
          orderBy: jest.fn().mockReturnValue({ limit: jest.fn().mockResolvedValue([]) }),
        }),
      }),
    }),
  });
  mockDb.update.mockImplementation(() => {
    const set = jest.fn().mockReturnValue({
      where: jest.fn().mockResolvedValue([]),
    });
    return { set };
  });
  mockDb.delete.mockReturnValue({
    where: jest.fn().mockResolvedValue([]),
  });

  mockFbService.sendTextMessage.mockResolvedValue({ recipient_id: 'test' });
  mockFbService.sendQuickReplies.mockResolvedValue({ recipient_id: 'test' });
  mockFbService.sendGenericTemplate.mockResolvedValue({ recipient_id: 'test' });
  mockFbService.getUserProfile.mockResolvedValue(null);

  mockSmsService.sendVisitConfirmation.mockResolvedValue({ success: true });
  mockSmsService.sendTenantConfirmationRequest.mockResolvedValue({ success: true });
  mockSmsService.sendOccupantAccessRequest.mockResolvedValue({ success: true });
  mockSmsService.sendLeadFollowUpSms.mockResolvedValue({ success: true });
  mockCheckVisitConflict.mockResolvedValue(null);
  mockCheckScheduleAvailability.mockResolvedValue(null);

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

  it('hydrates a persisted conversation after restart and resumes from the saved state', async () => {
    const persistedConversation = {
      senderId: 'sender-restart',
      state: 'ASKED_REASON',
      leadId: 'lead-123',
      language: 'en',
      firstName: 'Ada',
      lastName: 'Lovelace',
      selectedBuildingId: 'building-1',
      selectedUnitId: 'unit-1',
      lastActivityAt: new Date('2026-05-10T04:00:00.000Z'),
      conversationData: {
        reason: 'work',
        communicationLogIds: [11, 12],
      },
    };

    mockDb.select.mockReturnValueOnce({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([persistedConversation]),
        }),
      }),
    });

    await botService.handleIncomingMessage('sender-restart', 'full time');

    expect(mockFbService.sendQuickReplies).toHaveBeenCalledWith(
      'sender-restart',
      'What is your current employment status?',
      expect.any(Array),
    );
    expect(mockFbService.getUserProfile).not.toHaveBeenCalled();
  });


  it('backfills pre-lead Messenger logs onto the created lead once budget is collected', async () => {
    const listingSelect = {
      from: jest.fn().mockReturnValue({
        innerJoin: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue([
              {
                unit: { id: 'unit-1' },
                building: { id: 'building-1', name: 'Le Château', address: '123 Rue Test' },
              },
            ]),
          }),
        }),
      }),
    };

    mockDb.select
      .mockReturnValueOnce(mockMessengerConversationSelect())
      .mockReturnValueOnce(listingSelect);

    let communicationLogId = 0;
    mockDb.insert.mockImplementation((table) => ({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue(
          table === 'leadsTable'
            ? [{ id: 'lead-backfill', fullName: 'Jean Tremblay' }]
            : table === 'communicationLogsTable'
              ? [{ id: `comm-${++communicationLogId}` }]
              : [{ id: 1 }],
        ),
      }),
    }));

    await botService.handleIncomingMessage('sender-backfill', 'bonjour');
    await botService.handleIncomingMessage('sender-backfill', 'français');
    await botService.handleIncomingMessage('sender-backfill', 'travail');
    await botService.handleIncomingMessage('sender-backfill', 'temps plein');
    await botService.handleIncomingMessage('sender-backfill', '2');
    await botService.handleIncomingMessage('sender-backfill', 'non');
    await botService.handleIncomingMessage('sender-backfill', '1200');

    expect(mockDb.update).toHaveBeenCalledWith('communicationLogsTable');
    expect(mockDb.update.mock.results[0].value.set).toHaveBeenCalledWith(expect.objectContaining({
      leadId: 'lead-backfill',
    }));
    expect(mockCommunicationThreadService.refreshCommunicationThread).toHaveBeenCalledWith('lead-backfill', {
      includeMessages: false,
    });
  });

  it('creates messenger-booked visits with confirmation token and shared visit notifications', async () => {
    const listingSelect = {
      from: jest.fn().mockReturnValue({
        innerJoin: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue([
              {
                unit: { id: 'unit-1' },
                building: { id: 'building-1', name: 'Le Château', address: '123 Rue Test' },
              },
            ]),
          }),
        }),
      }),
    };
    const slotSelect = {
      from: jest.fn().mockReturnValue({
        innerJoin: jest.fn().mockReturnValue({
          innerJoin: jest.fn().mockReturnValue({
            where: jest.fn().mockReturnValue({
              orderBy: jest.fn().mockReturnValue({
                limit: jest.fn().mockResolvedValue([
                  {
                    employeeId: 'emp-1',
                    firstName: 'Simon',
                    lastName: 'Roy',
                    phone: '+151****0123',
                    startTime: '09:00',
                    endTime: '17:00',
                  },
                ]),
              }),
            }),
          }),
        }),
      }),
    };
    const occupiedUnitSelect = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([{ status: 'occupied', tenantPhone: '+151****0999' }]),
        }),
      }),
    };

    mockDb.select
      .mockReturnValueOnce(mockMessengerConversationSelect())
      .mockReturnValueOnce(listingSelect)
      .mockReturnValueOnce(slotSelect)
      .mockReturnValueOnce(occupiedUnitSelect);

    mockDb.insert.mockImplementation((table) => ({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue(
          table === 'leadsTable'
            ? [{ id: 'lead-1', fullName: 'Jean Tremblay' }]
            : table === 'visitsTable'
              ? [{ id: 'visit-1', status: 'scheduled' }]
              : [{ id: 1 }],
        ),
      }),
    }));

    await botService.handleIncomingMessage('sender-visit', 'bonjour');
    await botService.handleIncomingMessage('sender-visit', 'français');
    await botService.handleIncomingMessage('sender-visit', 'travail');
    await botService.handleIncomingMessage('sender-visit', 'temps plein');
    await botService.handleIncomingMessage('sender-visit', '2');
    await botService.handleIncomingMessage('sender-visit', 'non');
    await botService.handleIncomingMessage('sender-visit', '1200');
    await botService.handlePostback('sender-visit', 'SELECT_UNIT_unit-1_building-1');
    await botService.handlePostback('sender-visit', 'VISIT_YES');

    const visitInsertIndex = mockDb.insert.mock.calls.findIndex(([table]) => table === 'visitsTable');
    expect(visitInsertIndex).toBeGreaterThan(-1);
    const visitInsertValues = mockDb.insert.mock.results[visitInsertIndex].value.values.mock.calls[0][0];

    const leadUpdatePayloads = getLeadUpdatePayloads();
    expect(leadUpdatePayloads).toEqual(expect.arrayContaining([
      expect.objectContaining({
        stage: 'qualifie',
        qualificationState: 'qualified',
        qualificationReasonCode: 'other',
      }),
      expect.objectContaining({
        stage: 'visite_planifiee',
        qualificationState: 'qualified',
        qualificationReasonCode: 'other',
      }),
    ]));
    expect(leadUpdatePayloads.at(-1)).toEqual(expect.objectContaining({
      stage: 'visite_planifiee',
      qualificationState: 'qualified',
      qualificationReasonNote: expect.stringContaining('Visit scheduled from Messenger qualification.'),
    }));

    expect(visitInsertValues).toEqual(expect.objectContaining({
      unitId: 'unit-1',
      employeeId: 'emp-1',
      leadId: 'lead-1',
      status: 'scheduled',
      confirmationToken: 'token-abc',
    }));
    expect(mockSmsService.sendVisitConfirmation).toHaveBeenCalledWith('visit-1');
    expect(mockSmsService.sendTenantConfirmationRequest).toHaveBeenCalledWith('visit-1');
    expect(mockSmsService.sendOccupantAccessRequest).toHaveBeenCalledWith('visit-1');
    expect(mockCommunicationThreadService.refreshCommunicationThread).toHaveBeenNthCalledWith(1, 'lead-1', {
      includeMessages: false,
    });
    expect(mockCommunicationThreadService.refreshCommunicationThread).toHaveBeenNthCalledWith(2, 'lead-1', {
      includeMessages: false,
    });
    expect(mockCommunicationThreadService.refreshCommunicationThread).toHaveBeenNthCalledWith(3, 'lead-1', {
      includeMessages: false,
    });
  });

  it('logs the no-listings handoff when availability disappears before visit booking', async () => {
    const initialListingSelect = {
      from: jest.fn().mockReturnValue({
        innerJoin: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue([
              {
                unit: { id: 'unit-1' },
                building: { id: 'building-1', name: 'Le Château', address: '123 Rue Test' },
              },
            ]),
          }),
        }),
      }),
    };
    const emptyListingSelect = {
      from: jest.fn().mockReturnValue({
        innerJoin: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue([]),
          }),
        }),
      }),
    };

    mockDb.select
      .mockReturnValueOnce(mockMessengerConversationSelect())
      .mockReturnValueOnce(initialListingSelect)
      .mockReturnValueOnce(emptyListingSelect);

    mockDb.insert.mockImplementation((table) => ({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue(
          table === 'leadsTable'
            ? [{ id: 'lead-vanished', fullName: 'Jean Tremblay' }]
            : [{ id: 1 }],
        ),
      }),
    }));

    await botService.handleIncomingMessage('sender-no-listings', 'bonjour');
    await botService.handleIncomingMessage('sender-no-listings', 'français');
    await botService.handleIncomingMessage('sender-no-listings', 'travail');
    await botService.handleIncomingMessage('sender-no-listings', 'temps plein');
    await botService.handleIncomingMessage('sender-no-listings', '2');
    await botService.handleIncomingMessage('sender-no-listings', 'non');
    await botService.handleIncomingMessage('sender-no-listings', '1200');
    await botService.handleIncomingMessage('sender-no-listings', 'n\'importe');
    await botService.handlePostback('sender-no-listings', 'VISIT_YES');

    const leadUpdatePayloads = getLeadUpdatePayloads();
    expect(leadUpdatePayloads).toEqual(expect.arrayContaining([
      expect.objectContaining({
        stage: 'qualifie',
        qualificationState: 'qualified',
        qualificationReasonCode: 'other',
      }),
      expect.objectContaining({
        stage: 'contacte',
        qualificationState: 'needs_follow_up',
        qualificationReasonCode: 'budget_mismatch',
      }),
    ]));
    expect(leadUpdatePayloads.at(-1).qualificationReasonNote).toContain('No matching listings were found when the user requested a visit.');

    const communicationPayloads = mockDb.insert.mock.calls
      .map(([table], index) => (table === 'communicationLogsTable'
        ? mockDb.insert.mock.results[index].value.values.mock.calls[0][0]
        : null))
      .filter(Boolean);

    expect(communicationPayloads).toEqual(expect.arrayContaining([
      expect.objectContaining({
        leadId: 'lead-vanished',
        direction: 'outbound',
        content: 'Désolé, je n\'ai pas de logements disponibles correspondant à vos critères. Je transfère votre demande à Simon.',
      }),
    ]));
  });

  it('marks a lead as rejected when the user declines the visit after qualification', async () => {
    const listingSelect = {
      from: jest.fn().mockReturnValue({
        innerJoin: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue([
              {
                unit: { id: 'unit-1' },
                building: { id: 'building-1', name: 'Le Château', address: '123 Rue Test' },
              },
            ]),
          }),
        }),
      }),
    };

    mockDb.select
      .mockReturnValueOnce(mockMessengerConversationSelect())
      .mockReturnValueOnce(listingSelect);

    mockDb.insert.mockImplementation((table) => ({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue(
          table === 'leadsTable'
            ? [{ id: 'lead-decline', fullName: 'Jean Tremblay' }]
            : [{ id: 1 }],
        ),
      }),
    }));

    await botService.handleIncomingMessage('sender-decline', 'bonjour');
    await botService.handleIncomingMessage('sender-decline', 'français');
    await botService.handleIncomingMessage('sender-decline', 'travail');
    await botService.handleIncomingMessage('sender-decline', 'temps plein');
    await botService.handleIncomingMessage('sender-decline', '2');
    await botService.handleIncomingMessage('sender-decline', 'non');
    await botService.handleIncomingMessage('sender-decline', '1200');
    await botService.handlePostback('sender-decline', 'SELECT_UNIT_unit-1_building-1');
    await botService.handlePostback('sender-decline', 'VISIT_NO');

    const leadUpdatePayloads = getLeadUpdatePayloads();
    expect(leadUpdatePayloads).toEqual(expect.arrayContaining([
      expect.objectContaining({
        stage: 'qualifie',
        qualificationState: 'qualified',
      }),
      expect.objectContaining({
        stage: 'inactif',
        qualificationState: 'rejected',
        qualificationReasonCode: 'no_longer_interested',
      }),
    ]));
    expect(leadUpdatePayloads.at(-1).qualificationReasonNote).toContain('User declined the visit request.');
  });

  it('skips conflicting messenger visit slots and books the next valid employee slot', async () => {
    const listingSelect = {
      from: jest.fn().mockReturnValue({
        innerJoin: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue([
              {
                unit: { id: 'unit-1' },
                building: { id: 'building-1', name: 'Le Château', address: '123 Rue Test' },
              },
            ]),
          }),
        }),
      }),
    };
    const slotSelect = {
      from: jest.fn().mockReturnValue({
        innerJoin: jest.fn().mockReturnValue({
          innerJoin: jest.fn().mockReturnValue({
            where: jest.fn().mockReturnValue({
              orderBy: jest.fn().mockReturnValue({
                limit: jest.fn().mockResolvedValue([
                  {
                    employeeId: 'emp-1',
                    firstName: 'Simon',
                    lastName: 'Roy',
                    phone: '+151****0123',
                    startTime: '09:00',
                    endTime: '17:00',
                  },
                  {
                    employeeId: 'emp-2',
                    firstName: 'Julie',
                    lastName: 'Fortin',
                    phone: '+151****0456',
                    startTime: '10:00',
                    endTime: '18:00',
                  },
                ]),
              }),
            }),
          }),
        }),
      }),
    };
    const vacantUnitSelect = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([{ status: 'vacant', tenantPhone: null }]),
        }),
      }),
    };

    mockDb.select
      .mockReturnValueOnce(mockMessengerConversationSelect())
      .mockReturnValueOnce(listingSelect)
      .mockReturnValueOnce(slotSelect)
      .mockReturnValueOnce(vacantUnitSelect);

    mockCheckVisitConflict
      .mockResolvedValueOnce({ id: 'visit-existing' })
      .mockResolvedValueOnce(null);

    mockDb.insert.mockImplementation((table) => ({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue(
          table === 'leadsTable'
            ? [{ id: 'lead-1', fullName: 'Jean Tremblay' }]
            : table === 'visitsTable'
              ? [{ id: 'visit-2', status: 'scheduled' }]
              : [{ id: 1 }],
        ),
      }),
    }));

    await botService.handleIncomingMessage('sender-visit-conflict', 'bonjour');
    await botService.handleIncomingMessage('sender-visit-conflict', 'français');
    await botService.handleIncomingMessage('sender-visit-conflict', 'travail');
    await botService.handleIncomingMessage('sender-visit-conflict', 'temps plein');
    await botService.handleIncomingMessage('sender-visit-conflict', '2');
    await botService.handleIncomingMessage('sender-visit-conflict', 'non');
    await botService.handleIncomingMessage('sender-visit-conflict', '1200');
    await botService.handlePostback('sender-visit-conflict', 'SELECT_UNIT_unit-1_building-1');
    await botService.handlePostback('sender-visit-conflict', 'VISIT_YES');

    const visitInsertIndex = mockDb.insert.mock.calls.findIndex(([table]) => table === 'visitsTable');
    expect(visitInsertIndex).toBeGreaterThan(-1);
    const visitInsertValues = mockDb.insert.mock.results[visitInsertIndex].value.values.mock.calls[0][0];

    expect(visitInsertValues).toEqual(expect.objectContaining({
      employeeId: 'emp-2',
      confirmationToken: 'token-abc',
    }));
    expect(mockCheckScheduleAvailability).toHaveBeenCalledTimes(2);
    expect(mockCheckVisitConflict).toHaveBeenCalledTimes(2);
    expect(mockSmsService.sendVisitConfirmation).toHaveBeenCalledWith('visit-2');
    expect(mockSmsService.sendOccupantAccessRequest).not.toHaveBeenCalled();
  });

  it('handles DONE state with thank you message', async () => {
    await botService.handleIncomingMessage('sender3', 'hello');
    await botService.handleIncomingMessage('sender3', 'français');
    await botService.handleIncomingMessage('sender3', 'travail');
    await botService.handleIncomingMessage('sender3', 'temps plein');
    await botService.handleIncomingMessage('sender3', '2');
    await botService.handleIncomingMessage('sender3', 'non');
    await botService.handleIncomingMessage('sender3', '1200');
    await botService.handleIncomingMessage('sender3', 'n\'importe');

    mockFbService.sendTextMessage.mockClear();
    await botService.handleIncomingMessage('sender3', 'merci');

    expect(mockFbService.sendTextMessage).toHaveBeenCalledWith(
      'sender3',
      expect.stringContaining('ImmoGestion'),
    );
  });

  it('hydrates persisted conversation state instead of restarting at NEW', async () => {
    mockDb.select.mockReturnValueOnce({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([
            {
              senderId: 'sender-persisted',
              state: 'ASKED_BUDGET',
              leadId: null,
              language: 'fr',
              firstName: 'Jean',
              lastName: 'Tremblay',
              selectedBuildingId: null,
              selectedUnitId: null,
              lastActivityAt: new Date('2026-05-06T18:00:00Z'),
              conversationData: {
                language: 'fr',
                reason: 'travail',
                employment: 'temps plein',
                occupants: 2,
                pets: 'no',
                communicationLogIds: ['comm-1'],
              },
            },
          ]),
        }),
      }),
    });

    await botService.handleIncomingMessage('sender-persisted', '1200');

    expect(mockFbService.sendTextMessage.mock.calls.some(([, message]) => message.includes('Bienvenue chez ImmoGestion'))).toBe(false);
    expect(mockFbService.sendTextMessage.mock.calls.some(([, message]) => message.includes('Désolé, je n\'ai pas de logements disponibles'))).toBe(true);
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

// ─── Messenger follow-up policy ───

describe('sendPolicyAwareFollowUp', () => {
  it('keeps seeded marketplace follow-ups local in demo mode', async () => {
    const originalMode = process.env.MARKETPLACE_DATA_MODE;
    process.env.MARKETPLACE_DATA_MODE = 'seeded';

    mockFbService.sendTextMessage.mockClear();
    mockSmsService.sendLeadFollowUpSms.mockClear();

    try {
      const result = await botService.sendPolicyAwareFollowUp({
        senderId: 'sender-demo',
        lead: {
          id: 'lead-demo',
          phone: '+15145550002',
          tags: { __DEMO_SEED__: true },
        },
        message: 'Bonjour — demo follow-up',
        conversationLastActivityAt: new Date('2026-05-05T10:00:00.000Z'),
        lastCommunicationAt: new Date('2026-05-05T09:30:00.000Z'),
      });

      expect(result).toMatchObject({
        success: true,
        transport: 'demo',
        fallbackUsed: false,
        demoMarketplaceMode: true,
      });
      expect(mockFbService.sendTextMessage).not.toHaveBeenCalled();
      expect(mockSmsService.sendLeadFollowUpSms).not.toHaveBeenCalled();
    } finally {
      process.env.MARKETPLACE_DATA_MODE = originalMode;
    }
  });

  it('routes stale follow-ups through SMS with a handoff reason', async () => {
    const result = await botService.sendPolicyAwareFollowUp({
      senderId: 'sender-stale',
      lead: {
        id: 'lead-stale',
        phone: '+15145550123',
      },
      message: 'Simon prendra contact avec vous bientôt.',
      conversationLastActivityAt: new Date(Date.now() - (25 * 60 * 60 * 1000)),
      context: 'test_follow_up',
    });

    expect(result).toEqual(expect.objectContaining({
      success: true,
      transport: 'sms',
      fallbackUsed: true,
      handoffReason: 'meta_24h_window_expired',
    }));
    expect(mockSmsService.sendLeadFollowUpSms).toHaveBeenCalledWith(expect.objectContaining({
      leadId: 'lead-stale',
      phoneNumber: '+15145550123',
      messageBody: 'Simon prendra contact avec vous bientôt.',
    }));
    expect(mockFbService.sendTextMessage).not.toHaveBeenCalled();
  });

  it('records a failed communication when no phone number is available for SMS fallback', async () => {
    const result = await botService.sendPolicyAwareFollowUp({
      senderId: 'sender-no-phone',
      lead: {
        id: 'lead-no-phone',
        phone: null,
      },
      message: 'Simon prendra contact avec vous bientôt.',
      conversationLastActivityAt: new Date(Date.now() - (25 * 60 * 60 * 1000)),
      context: 'test_follow_up',
    });

    expect(result).toEqual(expect.objectContaining({
      success: false,
      transport: 'fb_messenger',
      fallbackUsed: false,
      handoffReason: 'meta_24h_window_expired',
    }));

    const failedLogInsert = mockDb.insert.mock.calls.find(([table]) => table === 'communicationLogsTable');
    expect(failedLogInsert).toBeDefined();
  });

  it('treats a fresh conversation as Messenger-eligible', () => {
    expect(botService.isMessengerFollowUpExpired({
      conversationLastActivityAt: new Date(Date.now() - (2 * 60 * 60 * 1000)),
    })).toBe(false);
  });

  it('marks a stale conversation as expired after 24 hours', () => {
    expect(botService.isMessengerFollowUpExpired({
      conversationLastActivityAt: new Date(Date.now() - (25 * 60 * 60 * 1000)),
    })).toBe(true);
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
