// Mock database
jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn(),
    insert: jest.fn(),
    update: jest.fn(),
  },
}));

const { db } = require('../src/database/connection');
const renewalController = require('../src/controllers/renewal.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

// ─── createRenewalOffer validation ───

describe('renewal.controller — createRenewalOffer', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('rejects missing leaseId', async () => {
    await renewalController.createRenewalOffer(
      { body: { newRent: 1200, newStartDate: '2026-07-01', newEndDate: '2027-06-30' } },
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

  it('rejects missing newRent', async () => {
    await renewalController.createRenewalOffer(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', newStartDate: '2026-07-01', newEndDate: '2027-06-30' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing newStartDate', async () => {
    await renewalController.createRenewalOffer(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', newRent: 1200, newEndDate: '2027-06-30' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing newEndDate', async () => {
    await renewalController.createRenewalOffer(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', newRent: 1200, newStartDate: '2026-07-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects negative newRent', async () => {
    await renewalController.createRenewalOffer(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', newRent: -500, newStartDate: '2026-07-01', newEndDate: '2027-06-30' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects newEndDate before newStartDate', async () => {
    await renewalController.createRenewalOffer(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', newRent: 1200, newStartDate: '2027-06-30', newEndDate: '2026-07-01' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body', async () => {
    await renewalController.createRenewalOffer({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await renewalController.createRenewalOffer(
      { body: { leaseId: '00000000-0000-0000-0000-000000000001', newRent: 1200, newStartDate: '2026-07-01', newEndDate: '2027-06-30' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'RENEWAL_CREATION_FAILED' }),
      }),
    );
  });
});

// ─── getRenewalOffers ───

describe('renewal.controller — getRenewalOffers', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await renewalController.getRenewalOffers({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'RENEWAL_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── getRenewalOfferById ───

describe('renewal.controller — getRenewalOfferById', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await renewalController.getRenewalOfferById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'RENEWAL_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── updateRenewalOffer validation ───

describe('renewal.controller — updateRenewalOffer', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('rejects negative newRent', async () => {
    await renewalController.updateRenewalOffer(
      { params: { id: 'some-id' }, body: { newRent: -50 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await renewalController.updateRenewalOffer(
      { params: { id: 'some-id' }, body: { newRent: 1300 } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'RENEWAL_UPDATE_FAILED' }),
      }),
    );
  });
});

// ─── updateRenewalOfferStatus validation ───

describe('renewal.controller — updateRenewalOfferStatus', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('rejects missing status', async () => {
    await renewalController.updateRenewalOfferStatus(
      { params: { id: 'some-id' }, body: {} },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid status value', async () => {
    await renewalController.updateRenewalOfferStatus(
      { params: { id: 'some-id' }, body: { status: 'unknown' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await renewalController.updateRenewalOfferStatus(
      { params: { id: 'some-id' }, body: { status: 'sent' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'RENEWAL_STATUS_UPDATE_FAILED' }),
      }),
    );
  });
});

// ─── getLeasesNeedingRenewal ───

describe('renewal.controller — getLeasesNeedingRenewal', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await renewalController.getLeasesNeedingRenewal({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'RENEWAL_FETCH_FAILED' }),
      }),
    );
  });
});

// ─── sendRenewalNotification ───

describe('renewal.controller — sendRenewalNotification', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await renewalController.sendRenewalNotification({ params: { id: 'some-id' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'RENEWAL_NOTIFICATION_FAILED' }),
      }),
    );
  });
});

// ─── getRenewalOffersByLease ───

describe('renewal.controller — getRenewalOffersByLease', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await renewalController.getRenewalOffersByLease({ params: { id: 'some-id' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'RENEWAL_FETCH_FAILED' }),
      }),
    );
  });
});
