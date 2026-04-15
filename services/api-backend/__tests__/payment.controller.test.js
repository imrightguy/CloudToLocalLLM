// Mock database
jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn(),
    insert: jest.fn(),
    update: jest.fn(),
  },
}));

const { db } = require('../src/database/connection');
const paymentController = require('../src/controllers/payment.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

// ─── createPayment validation ───

describe('payment.controller — createPayment', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('rejects missing leaseId', async () => {
    await paymentController.createPayment(
      { body: { amount: 500, dueDate: '2026-06-01' } },
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

  it('rejects missing amount', async () => {
    await paymentController.createPayment(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', dueDate: '2026-06-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing dueDate', async () => {
    await paymentController.createPayment(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', amount: 500 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects negative amount', async () => {
    await paymentController.createPayment(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', amount: -100, dueDate: '2026-06-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid method', async () => {
    await paymentController.createPayment(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', amount: 500, dueDate: '2026-06-01', method: 'bitcoin' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body', async () => {
    await paymentController.createPayment({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });
});

// ─── getPayments ───

describe('payment.controller — getPayments', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await paymentController.getPayments({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PAYMENT_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── getPaymentById ───

describe('payment.controller — getPaymentById', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await paymentController.getPaymentById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PAYMENT_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── updatePayment validation ───

describe('payment.controller — updatePayment', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('rejects negative amount', async () => {
    await paymentController.updatePayment(
      { params: { id: 'some-id' }, body: { amount: -50 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await paymentController.updatePayment(
      { params: { id: 'some-id' }, body: { amount: 500 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PAYMENT_UPDATE_FAILED' }),
      }),
    );
  });
});

// ─── updatePaymentStatus validation ───

describe('payment.controller — updatePaymentStatus', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('rejects missing status', async () => {
    await paymentController.updatePaymentStatus(
      { params: { id: 'some-id' }, body: {} },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid status value', async () => {
    await paymentController.updatePaymentStatus(
      { params: { id: 'some-id' }, body: { status: 'unknown' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await paymentController.updatePaymentStatus(
      { params: { id: 'some-id' }, body: { status: 'paid' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PAYMENT_STATUS_UPDATE_FAILED' }),
      }),
    );
  });
});

// ─── deletePayment ───

describe('payment.controller — deletePayment', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await paymentController.deletePayment({ params: { id: 'some-id' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PAYMENT_DELETE_FAILED' }),
      }),
    );
  });
});

// ─── getPaymentsByLease ───

describe('payment.controller — getPaymentsByLease', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await paymentController.getPaymentsByLease({ params: { id: 'some-id' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PAYMENT_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── getLatePayments ───

describe('payment.controller — getLatePayments', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await paymentController.getLatePayments({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PAYMENT_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── calculateLateFeePreview ───

describe('payment.controller — calculateLateFeePreview', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await paymentController.calculateLateFeePreview({ params: { leaseId: 'some-id' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'PAYMENT_CALCULATION_FAILED' }),
      }),
    );
  });
});
