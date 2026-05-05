jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  ilike: jest.fn((col, val) => ({ _type: 'ilike', col, val })),
  or: jest.fn((...conds) => ({ _type: 'or', conds })),
  inArray: jest.fn((col, vals) => ({ _type: 'inArray', col, vals })),
}));

const mockDb = {
  select: jest.fn(),
  insert: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
};

jest.mock('../src/database/connection', () => ({ db: mockDb }));

jest.mock('../src/database/schema', () => ({
  communicationLogsTable: {
    id: 'communicationLogsTable.id',
    leadId: 'communicationLogsTable.leadId',
    employeeId: 'communicationLogsTable.employeeId',
    type: 'communicationLogsTable.type',
    direction: 'communicationLogsTable.direction',
    subject: 'communicationLogsTable.subject',
    content: 'communicationLogsTable.content',
    attachments: 'communicationLogsTable.attachments',
    status: 'communicationLogsTable.status',
    metadata: 'communicationLogsTable.metadata',
    isActive: 'communicationLogsTable.isActive',
    createdAt: 'communicationLogsTable.createdAt',
  },
  communicationThreadsTable: {
    id: 'communicationThreadsTable.id',
    leadId: 'communicationThreadsTable.leadId',
    latestVisitId: 'communicationThreadsTable.latestVisitId',
    coordinationState: 'communicationThreadsTable.coordinationState',
    messageCount: 'communicationThreadsTable.messageCount',
    lastMessageAt: 'communicationThreadsTable.lastMessageAt',
    lastMessageType: 'communicationThreadsTable.lastMessageType',
    lastMessageDirection: 'communicationThreadsTable.lastMessageDirection',
  },
  leadsTable: {
    id: 'leadsTable.id',
    fullName: 'leadsTable.fullName',
    phone: 'leadsTable.phone',
    email: 'leadsTable.email',
    stage: 'leadsTable.stage',
    source: 'leadsTable.source',
    desiredUnit: 'leadsTable.desiredUnit',
    assignedEmployeeId: 'leadsTable.assignedEmployeeId',
    notes: 'leadsTable.notes',
    createdAt: 'leadsTable.createdAt',
    updatedAt: 'leadsTable.updatedAt',
    isActive: 'leadsTable.isActive',
  },
  visitsTable: {
    id: 'visitsTable.id',
    leadId: 'visitsTable.leadId',
    unitId: 'visitsTable.unitId',
    employeeId: 'visitsTable.employeeId',
    dateTime: 'visitsTable.dateTime',
    durationMinutes: 'visitsTable.durationMinutes',
    status: 'visitsTable.status',
    tenantConfirmed: 'visitsTable.tenantConfirmed',
    employeeConfirmed: 'visitsTable.employeeConfirmed',
    morningOfSent: 'visitsTable.morningOfSent',
    outcome: 'visitsTable.outcome',
    reasonCode: 'visitsTable.reasonCode',
    completedAt: 'visitsTable.completedAt',
    cancelledAt: 'visitsTable.cancelledAt',
    noShowAt: 'visitsTable.noShowAt',
    rescheduledAt: 'visitsTable.rescheduledAt',
    notes: 'visitsTable.notes',
    createdAt: 'visitsTable.createdAt',
    updatedAt: 'visitsTable.updatedAt',
    isActive: 'visitsTable.isActive',
  },
}));

jest.mock('../src/utils/logger', () => ({
  child: jest.fn(() => ({
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    debug: jest.fn(),
  })),
}));

jest.mock('../src/controllers/visit.controller', () => ({
  createVisit: jest.fn(async (req, res) => {
    res.status(201).json({ success: true, data: { id: 'visit-1', leadId: req.body.leadId } });
  }),
}));

const service = require('../src/services/communication-thread.service');

function mockInsertChain(record) {
  return {
    values: jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([record]),
    }),
  };
}

function mockUpdateChain() {
  return {
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockResolvedValue([{ id: 'updated' }]),
    }),
  };
}

function mockSelectChainLead(lead) {
  return {
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue([lead]),
    orderBy: jest.fn().mockReturnThis(),
  };
}

function mockSelectChainRefreshFailure() {
  return {
    from: jest.fn(() => {
      throw new Error('refresh failed');
    }),
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockResolvedValue([]),
    orderBy: jest.fn().mockReturnThis(),
  };
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('communication-thread service best-effort thread refresh', () => {
  it('still returns 201 when marketplace message thread refresh fails', async () => {
    const record = {
      id: 'comm-1',
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Bonjour, je suis intéressé',
      createdAt: new Date('2026-05-05T15:00:00Z'),
    };

    mockDb.insert.mockReturnValue(mockInsertChain(record));
    mockDb.update.mockReturnValue(mockUpdateChain());
    mockDb.select
      .mockReturnValueOnce(mockSelectChainLead({ id: 'lead-1', stage: 'nouveau' }))
      .mockReturnValueOnce(mockSelectChainRefreshFailure());

    const result = await service.recordCommunicationActivity({
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Bonjour, je suis intéressé',
    });

    expect(result.statusCode).toBe(201);
    expect(result.body).toMatchObject({
      success: true,
      data: expect.objectContaining({ id: 'comm-1', leadId: 'lead-1' }),
    });
    expect(mockDb.select).toHaveBeenCalledTimes(2);
  });

  it('normalizes structured marketplace payloads instead of throwing on trim', async () => {
    const record = {
      id: 'comm-2',
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      content: '{"text":"Bonjour"}',
      createdAt: new Date('2026-05-05T15:01:00Z'),
    };

    mockDb.insert.mockReturnValue(mockInsertChain(record));
    mockDb.update.mockReturnValue(mockUpdateChain());
    mockDb.select
      .mockReturnValueOnce(mockSelectChainLead({ id: 'lead-1', stage: 'nouveau' }))
      .mockReturnValueOnce(mockSelectChainRefreshFailure());

    const result = await service.recordCommunicationActivity({
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      subject: { label: 'Bonjour' },
      content: { text: 'Bonjour' },
      body: { text: 'Fallback body' },
      status: { state: 'received' },
      attachments: { type: 'image' },
      metadata: { source: 'fb_webhook' },
    });

    expect(result.statusCode).toBe(201);
    expect(result.body).toMatchObject({
      success: true,
      data: expect.objectContaining({ id: 'comm-2', leadId: 'lead-1' }),
    });
    expect(mockDb.select).toHaveBeenCalledTimes(2);
  });

  it('downgrades unsupported inbound status values to a write-safe communication status', async () => {
    const record = {
      id: 'comm-3',
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      status: 'sent',
      createdAt: new Date('2026-05-05T15:02:00Z'),
    };

    const values = jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([record]),
    });
    mockDb.insert.mockReturnValue({ values });
    mockDb.update.mockReturnValue(mockUpdateChain());
    mockDb.select
      .mockReturnValueOnce(mockSelectChainLead({ id: 'lead-1', stage: 'nouveau' }))
      .mockReturnValueOnce(mockSelectChainRefreshFailure());

    const result = await service.recordCommunicationActivity({
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Bonjour',
      status: 'received',
    });

    expect(result.statusCode).toBe(201);
    expect(values).toHaveBeenCalledWith(expect.objectContaining({ status: 'received' }));
  });

  it('retries communication log writes with a fallback status when the live schema rejects received', async () => {
    const record = {
      id: 'comm-4',
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      status: 'sent',
      createdAt: new Date('2026-05-05T15:03:00Z'),
    };

    const statusConstraintError = Object.assign(new Error('check violation on communication_logs_status_check'), {
      code: '23514',
      constraint: 'communication_logs_status_check',
    });

    const firstValues = jest.fn().mockReturnValue({
      returning: jest.fn().mockRejectedValue(statusConstraintError),
    });
    const secondValues = jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([record]),
    });
    mockDb.insert
      .mockReturnValueOnce({ values: firstValues })
      .mockReturnValueOnce({ values: secondValues });
    mockDb.update.mockReturnValue(mockUpdateChain());
    mockDb.select
      .mockReturnValueOnce(mockSelectChainLead({ id: 'lead-1', stage: 'nouveau' }))
      .mockReturnValueOnce(mockSelectChainRefreshFailure());

    const result = await service.recordCommunicationActivity({
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Bonjour',
      status: 'received',
    });

    expect(result.statusCode).toBe(201);
    expect(firstValues).toHaveBeenCalledWith(expect.objectContaining({ status: 'received' }));
    expect(secondValues).toHaveBeenCalledWith(expect.objectContaining({ status: 'sent' }));
  });

  it('retries lead-linked communication logs without leadId when the initial insert fails', async () => {
    const record = {
      id: 'comm-6',
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      status: 'sent',
      createdAt: new Date('2026-05-05T15:05:00Z'),
    };

    const leadLinkedError = Object.assign(new Error('insert failed on lead-linked communication log'), {
      code: 'XX000',
    });

    const firstValues = jest.fn().mockReturnValue({
      returning: jest.fn().mockRejectedValue(leadLinkedError),
    });
    const secondValues = jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([record]),
    });
    mockDb.insert
      .mockReturnValueOnce({ values: firstValues })
      .mockReturnValueOnce({ values: secondValues });
    mockDb.update.mockReturnValue(mockUpdateChain());
    mockDb.select
      .mockReturnValueOnce(mockSelectChainLead({ id: 'lead-1', stage: 'nouveau' }))
      .mockReturnValueOnce(mockSelectChainRefreshFailure());

    const result = await service.recordCommunicationActivity({
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Bonjour',
    });

    expect(result.statusCode).toBe(201);
    expect(firstValues).toHaveBeenCalledWith(expect.objectContaining({ leadId: 'lead-1' }));
    expect(secondValues.mock.calls[0][0].leadId).toBeUndefined();
    expect(result.body.data).toMatchObject({ id: 'comm-6', leadId: 'lead-1' });
  });


  it('keeps the fallback communication log when relinking it to the lead fails', async () => {
    const record = {
      id: 'comm-7',
      leadId: null,
      type: 'fb_messenger',
      direction: 'inbound',
      status: 'sent',
      createdAt: new Date('2026-05-05T15:06:00Z'),
    };

    const leadLinkedError = Object.assign(new Error('insert failed on lead-linked communication log'), {
      code: 'XX000',
    });
    const relinkError = Object.assign(new Error('update failed when linking communication log to lead'), {
      code: 'XX001',
    });

    const firstValues = jest.fn().mockReturnValue({
      returning: jest.fn().mockRejectedValue(leadLinkedError),
    });
    const secondValues = jest.fn().mockReturnValue({
      returning: jest.fn().mockResolvedValue([record]),
    });
    mockDb.insert
      .mockReturnValueOnce({ values: firstValues })
      .mockReturnValueOnce({ values: secondValues });
    mockDb.update.mockReturnValue({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockRejectedValue(relinkError),
      }),
    });
    mockDb.select
      .mockReturnValueOnce(mockSelectChainLead({ id: 'lead-1', stage: 'nouveau' }))
      .mockReturnValueOnce(mockSelectChainRefreshFailure());

    const result = await service.recordCommunicationActivity({
      leadId: 'lead-1',
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Bonjour',
    });

    expect(result.statusCode).toBe(201);
    expect(secondValues.mock.calls[0][0].leadId).toBeUndefined();
    expect(result.body.data).toMatchObject({ id: 'comm-7', leadId: 'lead-1' });
    expect(mockDb.delete).not.toHaveBeenCalled();
  });

  it('still returns the visit result when thread refresh fails after scheduling', async () => {
    mockDb.update.mockReturnValue(mockUpdateChain());
    mockDb.select
      .mockReturnValueOnce(mockSelectChainLead({ id: 'lead-1', stage: 'nouveau' }))
      .mockReturnValueOnce(mockSelectChainRefreshFailure());

    const result = await service.recordMarketplaceVisit('lead-1', {
      unitId: 'unit-1',
      employeeId: 'employee-1',
      dateTime: '2026-05-06T10:00:00Z',
    });

    expect(result.statusCode).toBe(201);
    expect(result.body).toMatchObject({ success: true, data: { id: 'visit-1', leadId: 'lead-1' } });
    expect(mockDb.select).toHaveBeenCalledTimes(2);
  });
});
