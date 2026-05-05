jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

jest.mock('../../src/models/renovation', () => ({
  renovationRecordSchema: {
    validate: jest.fn((body) => (!body.unitId || !body.title ? { error: { details: [{ message: 'Validation failed' }] } } : { error: null, value: body })),
  },
  updateRenovationRecordSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
  renovationTaskSchema: {
    validate: jest.fn((body) => (!body.renovationRecordId || !body.title ? { error: { details: [{ message: 'Validation failed' }] } } : { error: null, value: body })),
  },
  updateRenovationTaskSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
  renovationOrderSchema: {
    validate: jest.fn((body) => (!body.renovationRecordId || !body.vendorName || !body.itemName || !body.quantityOrdered ? { error: { details: [{ message: 'Validation failed' }] } } : { error: null, value: body })),
  },
  updateRenovationOrderSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
  receivingEventSchema: {
    validate: jest.fn((body) => (!body.quantityReceived ? { error: { details: [{ message: 'Validation failed' }] } } : { error: null, value: body })),
  },
  surplusItemSchema: {
    validate: jest.fn((body) => (!body.renovationRecordId || !body.itemName || !body.quantityAvailable ? { error: { details: [{ message: 'Validation failed' }] } } : { error: null, value: body })),
  },
  updateRenovationSurplusItemSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
  workerIntakeRecordSchema: {
    validate: jest.fn((body) => (!body.renovationRecordId || !body.sourcePhone || !body.messageBody ? { error: { details: [{ message: 'Validation failed' }] } } : { error: null, value: body })),
  },
  updateWorkerIntakeRecordSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
  VALID_RENOVATION_STATUS_TRANSITIONS: {
    planned: ['active', 'blocked', 'archived'],
    active: ['blocked', 'ready_for_leasing', 'archived'],
    blocked: ['active', 'ready_for_leasing', 'archived'],
    ready_for_leasing: ['completed', 'archived'],
    completed: ['archived'],
    archived: [],
  },
  VALID_RENOVATION_READINESS_TRANSITIONS: {
    not_started: ['in_progress'],
    in_progress: ['blocked', 'ready_to_list'],
    blocked: ['in_progress', 'ready_to_list'],
    ready_to_list: ['ready_for_leasing'],
    ready_for_leasing: ['ready'],
    ready: [],
  },
  VALID_RENOVATION_TASK_TRANSITIONS: {
    todo: ['in_progress', 'blocked', 'cancelled'],
    in_progress: ['blocked', 'done', 'cancelled'],
    blocked: ['in_progress', 'cancelled'],
    done: [],
    cancelled: [],
  },
  VALID_RENOVATION_ORDER_STATUSES: ['draft', 'ordered', 'partially_received', 'received', 'cancelled'],
  VALID_RENOVATION_ORDER_TRANSITIONS: {
    draft: ['ordered', 'cancelled'],
    ordered: ['partially_received', 'received', 'cancelled'],
    partially_received: ['received', 'cancelled'],
    received: [],
    cancelled: [],
  },
  VALID_RENOVATION_SURPLUS_TRANSITIONS: {
    available: ['reserved', 'used', 'discarded'],
    reserved: ['available', 'used', 'discarded'],
    used: [],
    discarded: [],
  },
  VALID_RENOVATION_INTAKE_MESSAGE_KINDS: ['update', 'missing_material', 'blocker', 'completion', 'surplus', 'general_note'],
  VALID_RENOVATION_INTAKE_STATUSES: ['new', 'triaged', 'linked', 'resolved', 'dismissed'],
  VALID_RENOVATION_INTAKE_STATUS_TRANSITIONS: {
    new: ['triaged', 'linked', 'resolved', 'dismissed'],
    triaged: ['linked', 'resolved', 'dismissed'],
    linked: ['resolved', 'dismissed'],
    resolved: [],
    dismissed: [],
  },
  hasVerificationEvidence: jest.fn((evidence) => Array.isArray(evidence) && evidence.length > 0),
}));

const mockSelectChain = () => {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  chain.innerJoin = jest.fn().mockReturnValue(chain);
  chain.leftJoin = jest.fn().mockReturnValue(chain);
  return chain;
};

let selectChain;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn(),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(),
      }),
    }),
  })),
  delete: jest.fn(() => ({
    where: jest.fn().mockResolvedValue(undefined),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/services/renovation-readiness.service', () => ({
  syncReadinessProjectionByRenovationRecordId: jest.fn().mockResolvedValue(null),
}));

jest.mock('../../src/database/schema', () => ({
  renovationsTable: {
    id: 'id',
    unitId: 'unitId',
    buildingId: 'buildingId',
    title: 'title',
    status: 'status',
    readinessState: 'readinessState',
    startDate: 'startDate',
    targetEndDate: 'targetEndDate',
    notes: 'notes',
    isActive: 'isActive',
    createdAt: 'createdAt',
    updatedAt: 'updatedAt',
  },
  renovationTasksTable: {
    id: 'id',
    renovationRecordId: 'renovationRecordId',
    assigneeEmployeeId: 'assigneeEmployeeId',
    title: 'title',
    description: 'description',
    status: 'status',
    dueDate: 'dueDate',
    completedAt: 'completedAt',
    verificationEvidence: 'verificationEvidence',
    notes: 'notes',
    isActive: 'isActive',
    createdAt: 'createdAt',
    updatedAt: 'updatedAt',
  },
  renovationOrdersTable: {
    id: 'id',
    renovationRecordId: 'renovationRecordId',
    taskId: 'taskId',
    vendorName: 'vendorName',
    itemName: 'itemName',
    quantityOrdered: 'quantityOrdered',
    quantityReceived: 'quantityReceived',
    status: 'status',
    orderedAt: 'orderedAt',
    expectedAt: 'expectedAt',
    notes: 'notes',
    isActive: 'isActive',
    createdAt: 'createdAt',
    updatedAt: 'updatedAt',
  },
  renovationReceivingEventsTable: {
    id: 'id',
    orderId: 'orderId',
    quantityReceived: 'quantityReceived',
    receivedAt: 'receivedAt',
    notes: 'notes',
    createdAt: 'createdAt',
  },
  renovationSurplusItemsTable: {
    id: 'id',
    renovationRecordId: 'renovationRecordId',
    sourceOrderId: 'sourceOrderId',
    taskId: 'taskId',
    itemName: 'itemName',
    quantityAvailable: 'quantityAvailable',
    status: 'status',
    location: 'location',
    notes: 'notes',
    isActive: 'isActive',
    createdAt: 'createdAt',
    updatedAt: 'updatedAt',
  },
  workerIntakeRecordsTable: {
    id: 'id',
    renovationRecordId: 'renovationRecordId',
    taskId: 'taskId',
    orderId: 'orderId',
    sourcePhone: 'sourcePhone',
    workerName: 'workerName',
    messageBody: 'messageBody',
    messageKind: 'messageKind',
    status: 'status',
    confidence: 'confidence',
    summary: 'summary',
    rawPayload: 'rawPayload',
    photoCount: 'photoCount',
    receivedAt: 'receivedAt',
    reviewedAt: 'reviewedAt',
    resolvedAt: 'resolvedAt',
    notes: 'notes',
    isActive: 'isActive',
    createdAt: 'createdAt',
    updatedAt: 'updatedAt',
  },
  unitReadinessTable: {
    id: 'id',
    unitId: 'unitId',
    currentRenovationRecordId: 'currentRenovationRecordId',
    opsStatus: 'opsStatus',
    leasingStatus: 'leasingStatus',
    blockingCount: 'blockingCount',
    blockingSummary: 'blockingSummary',
    readyAt: 'readyAt',
    handedOffAt: 'handedOffAt',
    leasedAt: 'leasedAt',
    updatedAt: 'updatedAt',
    createdAt: 'createdAt',
  },
  unitsTable: { id: 'id', buildingId: 'buildingId', label: 'label' },
  employeesTable: { id: 'id' },
}));

const renovationController = require('../../src/controllers/renovation.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
});

describe('renovation controller', () => {
  it('creates a renovation record successfully', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1', buildingId: 'building-1' }]);
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'reno-1', unitId: 'unit-1', buildingId: 'building-1', title: 'Apartment 4B' }]),
      }),
    });

    const res = mockRes();
    await renovationController.createRenovationRecord({ body: { unitId: 'unit-1', title: 'Apartment 4B' } }, res);

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('creates an order successfully', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'reno-1' }]);
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'order-1', renovationRecordId: 'reno-1', status: 'draft' }]),
      }),
    });

    const res = mockRes();
    await renovationController.createRenovationOrder({ body: { renovationRecordId: 'reno-1', vendorName: 'Home Depot', itemName: 'Paint', quantityOrdered: 3 } }, res);

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true, data: expect.objectContaining({ id: 'order-1' }) }));
  });

  it('maps partial receipts to partially_received', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'order-1', renovationRecordId: 'reno-1', quantityOrdered: 5, quantityReceived: 1 }]);
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'event-1', orderId: 'order-1', quantityReceived: 2 }]),
      }),
    });
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'order-1', quantityReceived: 3, status: 'partially_received' }]),
        }),
      }),
    });

    const res = mockRes();
    await renovationController.createReceivingEvent({ params: { id: 'order-1' }, body: { quantityReceived: 2 } }, res);

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true, data: expect.objectContaining({ order: expect.objectContaining({ status: 'partially_received' }) }) }));
  });

  it('rejects invalid surplus status transitions', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'surplus-1', status: 'used' }]);

    const res = mockRes();
    await renovationController.updateRenovationSurplusItem({ params: { id: 'surplus-1' }, body: { status: 'available' } }, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ error: expect.objectContaining({ code: 'INVALID_RENOVATION_SURPLUS_STATUS_TRANSITION' }) }));
  });

  it('auto-links missing material intake records to the latest open order', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'reno-1' }]);
    selectChain.orderBy.mockResolvedValueOnce([{ id: 'order-1', renovationRecordId: 'reno-1', taskId: 'task-1', status: 'ordered' }]);
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'intake-1', renovationRecordId: 'reno-1', orderId: 'order-1', taskId: 'task-1', status: 'linked' }]),
      }),
    });

    const res = mockRes();
    await renovationController.createRenovationWorkerIntakeRecord({ body: { renovationRecordId: 'reno-1', sourcePhone: '+151****0000', messageBody: 'Need 2 more boxes of tile', messageKind: 'missing_material', twilioMessageSid: 'SM999', mediaUrls: ['https://example.com/tile.jpg'], mediaContentTypes: ['image/jpeg'] } }, res);

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true, data: expect.objectContaining({ orderId: 'order-1', taskId: 'task-1', status: 'linked' }) }));
  });

  it('rejects done task creation without verification evidence', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'reno-1' }]);

    const res = mockRes();
    await renovationController.createRenovationTask({ body: { renovationRecordId: 'reno-1', title: 'Inspect paint', status: 'done' } }, res);

    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ error: expect.objectContaining({ code: 'MISSING_VERIFICATION_EVIDENCE' }) }));
  });

  it('rejects done task updates without verification evidence', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'task-1', renovationRecordId: 'reno-1', status: 'in_progress', verificationEvidence: [] }]);

    const res = mockRes();
    await renovationController.updateRenovationTask({ params: { id: 'task-1' }, body: { status: 'done' } }, res);

    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ error: expect.objectContaining({ code: 'MISSING_VERIFICATION_EVIDENCE' }) }));
  });

  it('allows done task updates when verification evidence is present', async () => {
    selectChain.limit.mockResolvedValueOnce([{ id: 'task-1', renovationRecordId: 'reno-1', status: 'in_progress', verificationEvidence: [] }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'task-1', status: 'done', completedAt: new Date('2026-05-02T19:00:00.000Z'), verificationEvidence: [{ type: 'artifact', summary: 'Photo set in shared drive', reference: 'drive://album/123' }] }]),
        }),
      }),
    });

    const res = mockRes();
    await renovationController.updateRenovationTask({ params: { id: 'task-1' }, body: { status: 'done', verificationEvidence: [{ type: 'artifact', summary: 'Photo set in shared drive', reference: 'drive://album/123' }] } }, res);

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true, data: expect.objectContaining({ status: 'done' }) }));
  });
});
