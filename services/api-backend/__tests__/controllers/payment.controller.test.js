jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
  lte: jest.fn((col, val) => ({ col, val, _type: 'lte' })),
  gte: jest.fn((col, val) => ({ col, val, _type: 'gte' })),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

jest.mock('../../src/models/payment', () => ({
  paymentSchema: {
    validate: jest.fn((body) => {
      if (!body.leaseId || !body.amount || !body.dueDate) {
        return { error: { details: [{ message: 'Validation failed' }] } };
      }
      return { error: null, value: body };
    }),
  },
  updatePaymentSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
  paymentStatusSchema: {
    validate: jest.fn((body) => {
      const valid = ['pending', 'paid', 'late', 'partial'];
      if (!valid.includes(body.status)) {return { error: { details: [{ message: 'Invalid status' }] } };}
      return { error: null, value: body };
    }),
  },
  VALID_STATUS_TRANSITIONS: {
    pending: ['paid', 'late', 'partial'],
    late: ['paid', 'partial'],
    partial: ['paid'],
    paid: [],
  },
}));

const mockSelectChain = () => {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  chain.leftJoin = jest.fn().mockReturnValue(chain);
  chain.innerJoin = jest.fn().mockReturnValue(chain);
  return chain;
};

let selectChain;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn(() => Promise.resolve([{
        id: 'payment-1', leaseId: 'lease-1', amountCents: 120000, lateFeeCents: 0,
        dueDate: new Date('2026-05-01'), status: 'pending', method: null,
      }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{
          id: 'payment-1', amountCents: 120000, lateFeeCents: 0,
          dueDate: new Date('2026-05-01'), status: 'paid',
        }])),
      }),
    }),
  })),
  transaction: jest.fn(async (cb) => cb(mockDb)),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  paymentsTable: {
    id: 'id', leaseId: 'leaseId', amountCents: 'amountCents', lateFeeCents: 'lateFeeCents',
    dueDate: 'dueDate', paidDate: 'paidDate', status: 'status', method: 'method',
    reference: 'reference', notes: 'notes', isActive: 'isActive',
    createdAt: 'createdAt', updatedAt: 'updatedAt',
  },
  leasesTable: {
    id: 'id', unitId: 'unitId', tenantFirstName: 'tenantFirstName', tenantLastName: 'tenantLastName',
    tenantEmail: 'tenantEmail', tenantPhone: 'tenantPhone', rentCents: 'rentCents',
    depositCents: 'depositCents', startDate: 'startDate', endDate: 'endDate',
    status: 'status', signedAt: 'signedAt', isActive: 'isActive',
  },
  unitsTable: { id: 'id', buildingId: 'buildingId', label: 'label', rentCents: 'rentCents', status: 'status' },
  buildingsTable: { id: 'id', name: 'name' },
}));

const paymentController = require('../../src/controllers/payment.controller');
const { db } = require('../../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

const futureDueDate = new Date(Date.now() + 30 * 86400000);
const pastDueDate = new Date(Date.now() - 10 * 86400000);

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
});

describe('createPayment', () => {
  it('returns 400 on validation error', async () => {
    const res = mockRes();
    await paymentController.createPayment({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await paymentController.createPayment({
      body: { leaseId: 'bad', amount: 1200, dueDate: futureDueDate },
    }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEASE_NOT_FOUND' }),
    }));
  });

  it('creates payment with pending status for future due date', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', rentCents: 120000 }]);
    const res = mockRes();
    await paymentController.createPayment({
      body: { leaseId: 'lease-1', amount: 1200, dueDate: futureDueDate },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        amount: 1200,
        lateFee: 0,
        status: 'pending',
      }),
    }));
  });

  it('creates payment with late status for past due date', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', rentCents: 120000 }]);
    const fkError = new Error('late');
    fkError.code = 'test';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{
          id: 'payment-1', leaseId: 'lease-1', amountCents: 120000, lateFeeCents: 6000,
          dueDate: pastDueDate, status: 'late', method: null,
        }]),
      }),
    });
    const res = mockRes();
    await paymentController.createPayment({
      body: { leaseId: 'lease-1', amount: 1200, dueDate: pastDueDate },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        status: 'late',
        lateFee: 60,
      }),
    }));
  });

  it('handles FK violation', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', rentCents: 120000 }]);
    const fkError = new Error('FK');
    fkError.code = '23503';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(fkError),
      }),
    });
    const res = mockRes();
    await paymentController.createPayment({
      body: { leaseId: 'lease-1', amount: 1200, dueDate: futureDueDate },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
    }));
  });
});

describe('getPayments', () => {
  it('returns paginated payments with amount conversion', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'payment-1', amountCents: 120000, lateFeeCents: 500 }]);
    const res = mockRes();
    await paymentController.getPayments({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({
        amount: 1200,
        lateFee: 5,
        total: 1205,
      })]),
      metadata: expect.objectContaining({ total: 1 }),
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await paymentController.getPayments({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

describe('getPaymentById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await paymentController.getPaymentById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'PAYMENT_NOT_FOUND' }),
    }));
  });

  it('returns payment with lease, unit, and building data', async () => {
    selectChain.from.mockReturnValue(selectChain);
    const payment = { id: 'payment-1', leaseId: 'lease-1', amountCents: 120000, lateFeeCents: 0, dueDate: futureDueDate };
    selectChain.limit.mockResolvedValueOnce([payment]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', unitId: 'unit-1', rentCents: 120000, depositCents: 0 }]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1', buildingId: 'bld-1' }]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'bld-1', name: 'Test' }]);
    const res = mockRes();
    await paymentController.getPaymentById({ params: { id: 'payment-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        amount: 1200,
        lease: expect.objectContaining({ rent: 1200 }),
        building: expect.objectContaining({ id: 'bld-1' }),
      }),
    }));
  });
});

describe('updatePayment', () => {
  it('returns 400 on validation error', async () => {
    const { updatePaymentSchema } = require('../../src/models/payment');
    updatePaymentSchema.validate.mockReturnValueOnce({ error: { details: [{ message: 'bad' }] } });
    const res = mockRes();
    await paymentController.updatePayment({ params: { id: 'payment-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when payment not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await paymentController.updatePayment({ params: { id: 'nonexistent' }, body: { amount: 1500 } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 when payment is already paid', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'payment-1', status: 'paid' }]);
    const res = mockRes();
    await paymentController.updatePayment({ params: { id: 'payment-1' }, body: { method: 'check' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'PAYMENT_ALREADY_PAID' }),
    }));
  });

  it('updates non-paid payment successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'payment-1', status: 'pending' }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'payment-1', amountCents: 150000, lateFeeCents: 0, status: 'pending' }]),
        }),
      }),
    });
    const res = mockRes();
    await paymentController.updatePayment({ params: { id: 'payment-1' }, body: { amount: 1500 } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ amount: 1500 }),
    }));
  });
});

describe('updatePaymentStatus', () => {
  it('returns 400 on validation error', async () => {
    const res = mockRes();
    await paymentController.updatePaymentStatus({ params: { id: 'payment-1' }, body: { status: 'invalid' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when payment not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await paymentController.updatePaymentStatus({ params: { id: 'nonexistent' }, body: { status: 'paid' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 for invalid transition', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'payment-1', status: 'paid' }]);
    const res = mockRes();
    await paymentController.updatePaymentStatus({ params: { id: 'payment-1' }, body: { status: 'pending' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_STATUS_TRANSITION' }),
    }));
  });

  it('allows valid transition pending -> paid', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'payment-1', status: 'pending', amountCents: 120000, dueDate: futureDueDate }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'payment-1', status: 'paid', amountCents: 120000, lateFeeCents: 0, paidDate: new Date() }]),
        }),
      }),
    });
    const res = mockRes();
    await paymentController.updatePaymentStatus({ params: { id: 'payment-1' }, body: { status: 'paid' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ status: 'paid' }),
    }));
  });
});

describe('deletePayment', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await paymentController.deletePayment({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 when payment is paid', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'payment-1', status: 'paid' }]);
    const res = mockRes();
    await paymentController.deletePayment({ params: { id: 'payment-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'PAYMENT_ALREADY_PAID' }),
    }));
  });

  it('soft-deletes non-paid payment', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'payment-1', status: 'pending' }]);
    const res = mockRes();
    await paymentController.deletePayment({ params: { id: 'payment-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: expect.stringContaining('supprimé'),
    }));
    expect(db.update).toHaveBeenCalled();
  });
});

describe('getPaymentsByLease', () => {
  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await paymentController.getPaymentsByLease({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEASE_NOT_FOUND' }),
    }));
  });

  it('returns payments for a lease', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1' }]);
    const chain2 = mockSelectChain();
    chain2.from.mockReturnValue(chain2);
    chain2.where.mockReturnValue(chain2);
    chain2.then = jest.fn((resolve) => {
      Promise.resolve([]).then(resolve);
    });
    const chain3 = mockSelectChain();
    chain3.from.mockReturnValue(chain3);
    chain3.where.mockReturnValue(chain3);
    chain3.orderBy.mockResolvedValueOnce([{ id: 'payment-1', amountCents: 120000, lateFeeCents: 0 }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(undefined),
      }),
    });
    mockDb.select
      .mockReturnValueOnce(selectChain)
      .mockReturnValueOnce(chain2)
      .mockReturnValueOnce(chain3);
    const res = mockRes();
    await paymentController.getPaymentsByLease({ params: { id: 'lease-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ amount: 1200 })]),
    }));
  });
});

describe('getLatePayments', () => {
  it('returns late payments with total late fees', async () => {
    const chain = mockSelectChain();
    chain.from.mockReturnValue(chain);
    chain.where.mockReturnValue(chain);
    chain.then = jest.fn((resolve) => {
      Promise.resolve([
        { id: 'payment-1', amountCents: 120000, lateFeeCents: 2400, status: 'late' },
        { id: 'payment-2', amountCents: 120000, lateFeeCents: 1200, status: 'late' },
      ]).then(resolve);
    });
    mockDb.select.mockReturnValueOnce(chain);
    const res = mockRes();
    await paymentController.getLatePayments({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      metadata: expect.objectContaining({ totalLateFees: 36 }),
    }));
  });
});

describe('calculateLateFeePreview', () => {
  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await paymentController.calculateLateFeePreview({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEASE_NOT_FOUND' }),
    }));
  });

  it('returns late fee preview for lease', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', rentCents: 120000 }]);
    mockDb.select.mockReturnValueOnce(selectChain);
    const res = mockRes();
    await paymentController.calculateLateFeePreview({ params: { id: 'lease-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        rentAmount: 1200,
        dailyRate: 0.1,
        graceDays: 3,
        maxPercent: 10,
      }),
    }));
  });
});
