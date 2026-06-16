const paymentController = require('../src/controllers/payment.controller');
const { VALID_STATUS_TRANSITIONS } = require('../src/models/payment');

jest.mock('../src/database/connection', () => {
  const mockDb = {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    delete: jest.fn().mockReturnThis(),
    values: jest.fn().mockReturnThis(),
    returning: jest.fn(),
    limit: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    innerJoin: jest.fn().mockReturnThis(),
    offset: jest.fn().mockReturnThis(),
  };
  return { db: mockDb };
});

const { db } = require('../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

const FAKE_LEASE = {
  id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  unitId: 'unit-1',
  rentCents: 120000,
  depositCents: 60000,
  startDate: '2025-01-01',
  endDate: '2025-12-31',
};

const FAKE_PAYMENT = {
  id: 'pay-1',
  leaseId: FAKE_LEASE.id,
  amountCents: 120000,
  lateFeeCents: 0,
  dueDate: new Date('2025-02-01'),
  status: 'pending',
  method: null,
  reference: null,
  notes: null,
  createdAt: new Date('2025-01-01'),
  updatedAt: new Date('2025-01-01'),
  isActive: true,
};

function setupDbChain(result) {
  const chain = {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    values: jest.fn().mockReturnThis(),
    returning: jest.fn().mockResolvedValue(Array.isArray(result) ? result : [result]),
    limit: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    innerJoin: jest.fn().mockReturnThis(),
    offset: jest.fn().mockReturnThis(),
  };
  jest.spyOn(db, 'select').mockReturnValue(chain);
  jest.spyOn(db, 'update').mockReturnValue(chain);
  jest.spyOn(db, 'insert').mockReturnValue(chain);
  return chain;
}

beforeEach(() => {
  jest.clearAllMocks();
});

// ─── createPayment validation ───

describe('createPayment', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing leaseId', async () => {
    await paymentController.createPayment(
      { body: { amount: 1000, dueDate: '2025-02-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('rejects invalid leaseId (not UUID)', async () => {
    await paymentController.createPayment(
      { body: { leaseId: 'not-a-uuid', amount: 1000, dueDate: '2025-02-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing amount', async () => {
    await paymentController.createPayment(
      { body: { leaseId: FAKE_LEASE.id, dueDate: '2025-02-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects negative amount', async () => {
    await paymentController.createPayment(
      { body: { leaseId: FAKE_LEASE.id, amount: -50, dueDate: '2025-02-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects zero amount', async () => {
    await paymentController.createPayment(
      { body: { leaseId: FAKE_LEASE.id, amount: 0, dueDate: '2025-02-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects amount exceeding max', async () => {
    await paymentController.createPayment(
      { body: { leaseId: FAKE_LEASE.id, amount: 2000000, dueDate: '2025-02-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing dueDate', async () => {
    await paymentController.createPayment(
      { body: { leaseId: FAKE_LEASE.id, amount: 1000 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid dueDate format', async () => {
    await paymentController.createPayment(
      { body: { leaseId: FAKE_LEASE.id, amount: 1000, dueDate: 'not-a-date' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body', async () => {
    await paymentController.createPayment({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid payment method', async () => {
    await paymentController.createPayment(
      {
        body: {
          leaseId: FAKE_LEASE.id,
          amount: 1000,
          dueDate: '2025-02-01',
          method: 'bitcoin',
        },
      },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when lease not found', async () => {
    db.select.mockReturnValue({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([]),
        }),
      }),
    });

    await paymentController.createPayment(
      {
        body: {
          leaseId: FAKE_LEASE.id,
          amount: 1000,
          dueDate: '2025-02-01',
        },
      },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'LEASE_NOT_FOUND' }),
      }),
    );
  });

  it('converts amount to cents on successful creation', async () => {
    db.select.mockReturnValue({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([FAKE_LEASE]),
        }),
      }),
    });
    db.insert.mockReturnValue({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([
          { ...FAKE_PAYMENT, amountCents: 95000 },
        ]),
      }),
    });

    await paymentController.createPayment(
      {
        body: {
          leaseId: FAKE_LEASE.id,
          amount: 950,
          dueDate: '2025-02-01',
        },
      },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(201);
    const data = res.json.mock.calls[0][0].data;
    expect(data.amount).toBe(950);
  });

  it('handles FK violation error', async () => {
    db.select.mockReturnValue({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockRejectedValue({ code: '23503' }),
        }),
      }),
    });

    await paymentController.createPayment(
      {
        body: {
          leaseId: FAKE_LEASE.id,
          amount: 1000,
          dueDate: '2025-02-01',
        },
      },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
      }),
    );
  });
});

// ─── updatePayment validation ───

describe('updatePayment', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects negative amount', async () => {
    await paymentController.updatePayment(
      { params: { id: 'pay-1' }, body: { amount: -10 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid paidDate', async () => {
    await paymentController.updatePayment(
      { params: { id: 'pay-1' }, body: { paidDate: 'not-a-date' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects negative lateFeeCents', async () => {
    await paymentController.updatePayment(
      { params: { id: 'pay-1' }, body: { lateFeeCents: -5 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects non-integer lateFeeCents', async () => {
    await paymentController.updatePayment(
      { params: { id: 'pay-1' }, body: { lateFeeCents: 1.5 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });
});

// ─── updatePaymentStatus validation ───

describe('updatePaymentStatus', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing status', async () => {
    await paymentController.updatePaymentStatus(
      { params: { id: 'pay-1' }, body: {} },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('rejects invalid status value', async () => {
    await paymentController.updatePaymentStatus(
      { params: { id: 'pay-1' }, body: { status: 'banana' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects transition from paid to any other status', async () => {
    const _chain = setupDbChain([FAKE_PAYMENT]);
    const selectChain = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([FAKE_PAYMENT]),
        }),
      }),
    };
    db.select.mockReturnValue(selectChain);

    await paymentController.updatePaymentStatus(
      { params: { id: 'pay-1' }, body: { status: 'pending' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'INVALID_STATUS_TRANSITION' }),
      }),
    );
  });

  it('rejects transition from pending to pending (same status)', async () => {
    const selectChain = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([{ ...FAKE_PAYMENT, status: 'pending' }]),
        }),
      }),
    };
    db.select.mockReturnValue(selectChain);

    await paymentController.updatePaymentStatus(
      { params: { id: 'pay-1' }, body: { status: 'pending' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });
});

// ─── deletePayment ───

describe('deletePayment', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 404 for non-existent payment', async () => {
    const selectChain = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([]),
        }),
      }),
    };
    db.select.mockReturnValue(selectChain);

    await paymentController.deletePayment(
      { params: { id: 'nonexistent' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'PAYMENT_NOT_FOUND' }),
      }),
    );
  });

  it('rejects deleting a paid payment', async () => {
    const selectChain = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([
            { ...FAKE_PAYMENT, status: 'paid' },
          ]),
        }),
      }),
    };
    db.select.mockReturnValue(selectChain);

    await paymentController.deletePayment(
      { params: { id: 'pay-1' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'PAYMENT_ALREADY_PAID' }),
      }),
    );
  });
});

// ─── getPaymentById ───

describe('getPaymentById', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 404 for non-existent payment', async () => {
    const selectChain = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([]),
        }),
      }),
    };
    db.select.mockReturnValue(selectChain);

    await paymentController.getPaymentById(
      { params: { id: 'nonexistent' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'PAYMENT_NOT_FOUND' }),
      }),
    );
  });
});

// ─── getPaymentsByLease ───

describe('getPaymentsByLease', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 404 for non-existent lease', async () => {
    const selectChain = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([]),
        }),
      }),
    };
    db.select.mockReturnValue(selectChain);

    await paymentController.getPaymentsByLease(
      { params: { id: 'nonexistent-lease' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'LEASE_NOT_FOUND' }),
      }),
    );
  });
});

// ─── calculateLateFeePreview ───

describe('calculateLateFeePreview', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns 404 for non-existent lease', async () => {
    const selectChain = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([]),
        }),
      }),
    };
    db.select.mockReturnValue(selectChain);

    await paymentController.calculateLateFeePreview(
      { params: { leaseId: 'nonexistent' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'LEASE_NOT_FOUND' }),
      }),
    );
  });

  it('returns correct fee structure for valid lease', async () => {
    const selectChain = {
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([FAKE_LEASE]),
        }),
      }),
    };
    db.select.mockReturnValue(selectChain);

    await paymentController.calculateLateFeePreview(
      { params: { leaseId: FAKE_LEASE.id } },
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({
          rentAmount: 1200,
          dailyRate: 0.1,
          graceDays: 3,
          maxPercent: 10,
        }),
      }),
    );
  });
});

// ─── getPayments pagination ───

describe('getPayments', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('returns payments with default pagination', async () => {
    db.select
      .mockReturnValueOnce({
        from: jest.fn().mockReturnValue({
          innerJoin: jest.fn().mockReturnValue({
            innerJoin: jest.fn().mockReturnValue({
              where: jest.fn().mockResolvedValue([{ count: 0 }]),
            }),
          }),
        }),
      })
      .mockReturnValueOnce({
        from: jest.fn().mockReturnValue({
          innerJoin: jest.fn().mockReturnValue({
            innerJoin: jest.fn().mockReturnValue({
              leftJoin: jest.fn().mockReturnValue({
                where: jest.fn().mockReturnValue({
                  orderBy: jest.fn().mockReturnValue({
                    limit: jest.fn().mockReturnValue({
                      offset: jest.fn().mockResolvedValue([FAKE_PAYMENT]),
                    }),
                  }),
                }),
              }),
            }),
          }),
        }),
      });

    await paymentController.getPayments({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.any(Array),
        metadata: expect.objectContaining({
          page: 1,
          limit: 20,
        }),
      }),
    );
  });

  it('applies status filter', async () => {
    db.select
      .mockReturnValueOnce({
        from: jest.fn().mockReturnValue({
          innerJoin: jest.fn().mockReturnValue({
            innerJoin: jest.fn().mockReturnValue({
              where: jest.fn().mockResolvedValue([{ count: 0 }]),
            }),
          }),
        }),
      })
      .mockReturnValueOnce({
        from: jest.fn().mockReturnValue({
          innerJoin: jest.fn().mockReturnValue({
            innerJoin: jest.fn().mockReturnValue({
              leftJoin: jest.fn().mockReturnValue({
                where: jest.fn().mockReturnValue({
                  orderBy: jest.fn().mockReturnValue({
                    limit: jest.fn().mockReturnValue({
                      offset: jest.fn().mockResolvedValue([]),
                    }),
                  }),
                }),
              }),
            }),
          }),
        }),
      });

    await paymentController.getPayments({ query: { status: 'late' } }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
  });
});

// ─── VALID_STATUS_TRANSITIONS ───

describe('VALID_STATUS_TRANSITIONS', () => {
  it('has no allowed transitions from paid', () => {
    expect(VALID_STATUS_TRANSITIONS.paid).toEqual([]);
  });

  it('allows pending to be marked paid, late, or partial', () => {
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('paid');
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('late');
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('partial');
  });

  it('allows late to be marked paid or partial', () => {
    expect(VALID_STATUS_TRANSITIONS.late).toContain('paid');
    expect(VALID_STATUS_TRANSITIONS.late).toContain('partial');
  });

  it('allows partial to be marked paid', () => {
    expect(VALID_STATUS_TRANSITIONS.partial).toEqual(['paid']);
  });
});
