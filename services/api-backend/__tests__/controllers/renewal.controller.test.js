jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
  lte: jest.fn((col, val) => ({ col, val, _type: 'lte' })),
  gte: jest.fn((col, val) => ({ col, val, _type: 'gte' })),
  ne: jest.fn((col, val) => ({ col, val, _type: 'ne' })),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

jest.mock('../../src/models/renewal', () => ({
  renewalOfferSchema: {
    validate: jest.fn((body) => {
      if (!body.leaseId || !body.newRent || !body.newStartDate || !body.newEndDate) {
        return { error: { details: [{ message: 'Validation failed' }] } };
      }
      return { error: null, value: body };
    }),
  },
  updateRenewalOfferSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
  renewalOfferStatusSchema: {
    validate: jest.fn((body) => {
      const valid = ['pending', 'sent', 'accepted', 'declined', 'expired'];
      if (!valid.includes(body.status)) {return { error: { details: [{ message: 'Invalid status' }] } };}
      return { error: null, value: body };
    }),
  },
  VALID_RENEWAL_TRANSITIONS: {
    pending: ['sent', 'expired'],
    sent: ['accepted', 'declined', 'expired'],
    accepted: [],
    declined: [],
    expired: [],
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
        id: 'renewal-1', leaseId: 'lease-1', newRentCents: 150000, newDepositCents: 0,
        newStartDate: new Date('2027-06-01'), newEndDate: new Date('2028-05-31'),
        status: 'pending', sentAt: null,
      }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{
          id: 'renewal-1', newRentCents: 150000, newDepositCents: 0,
          status: 'sent', sentAt: new Date(),
        }])),
      }),
    }),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  renewalOffersTable: {
    id: 'id', leaseId: 'leaseId', newStartDate: 'newStartDate', newEndDate: 'newEndDate',
    newRentCents: 'newRentCents', newDepositCents: 'newDepositCents', terms: 'terms',
    status: 'status', sentAt: 'sentAt', sentVia: 'sentVia', tenantResponse: 'tenantResponse',
    respondedAt: 'respondedAt', notes: 'notes', isActive: 'isActive',
    createdAt: 'createdAt', updatedAt: 'updatedAt',
  },
  leasesTable: {
    id: 'id', unitId: 'unitId', tenantFirstName: 'tenantFirstName', tenantLastName: 'tenantLastName',
    tenantEmail: 'tenantEmail', tenantPhone: 'tenantPhone', rentCents: 'rentCents',
    depositCents: 'depositCents', startDate: 'startDate', endDate: 'endDate',
    status: 'status', signedAt: 'signedAt', isActive: 'isActive',
  },
  unitsTable: { id: 'id', buildingId: 'buildingId', label: 'label', rentCents: 'rentCents', status: 'status' },
  buildingsTable: { id: 'id', name: 'name', address: 'address', city: 'city' },
  smsQueueTable: { id: 'id', leaseId: 'leaseId', reminderType: 'reminderType' },
}));

jest.mock('../../src/services/notification.service', () => ({
  notifyAdminsForEvent: jest.fn(() => Promise.resolve([])),
}));

const renewalController = require('../../src/controllers/renewal.controller');
const { db } = require('../../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

const futureStart = new Date(Date.now() + 365 * 86400000);
const futureEnd = new Date(Date.now() + 730 * 86400000);

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
});

describe('createRenewalOffer', () => {
  it('returns 400 on validation error', async () => {
    const res = mockRes();
    await renewalController.createRenewalOffer({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await renewalController.createRenewalOffer({
      body: { leaseId: 'bad', newRent: 1500, newStartDate: futureStart, newEndDate: futureEnd },
    }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEASE_NOT_FOUND' }),
    }));
  });

  it('returns 400 for non-active lease', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', status: 'draft' }]);
    const res = mockRes();
    await renewalController.createRenewalOffer({
      body: { leaseId: 'lease-1', newRent: 1500, newStartDate: futureStart, newEndDate: futureEnd },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_LEASE_STATUS' }),
    }));
  });

  it('creates renewal offer for active lease', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', status: 'active' }]);
    const res = mockRes();
    await renewalController.createRenewalOffer({
      body: { leaseId: 'lease-1', newRent: 1500, newStartDate: futureStart, newEndDate: futureEnd },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ newRent: 1500, status: 'pending' }),
    }));
  });
});

describe('getRenewalOffers', () => {
  it('returns paginated renewal offers', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'renewal-1', newRentCents: 150000, newDepositCents: 0, status: 'pending' }]);
    const res = mockRes();
    await renewalController.getRenewalOffers({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ newRent: 1500 })]),
      metadata: expect.objectContaining({ total: 1 }),
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await renewalController.getRenewalOffers({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

describe('getRenewalOfferById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await renewalController.getRenewalOfferById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'RENEWAL_NOT_FOUND' }),
    }));
  });

  it('returns renewal offer with lease data', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'renewal-1', leaseId: 'lease-1', newRentCents: 150000, newDepositCents: 0 }]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', rentCents: 120000, depositCents: 0 }]);
    const res = mockRes();
    await renewalController.getRenewalOfferById({ params: { id: 'renewal-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        newRent: 1500,
        lease: expect.objectContaining({ rent: 1200 }),
      }),
    }));
  });
});

describe('updateRenewalOffer', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await renewalController.updateRenewalOffer({ params: { id: 'nonexistent' }, body: { newRent: 1600 } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 for accepted offer', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'renewal-1', status: 'accepted' }]);
    const res = mockRes();
    await renewalController.updateRenewalOffer({ params: { id: 'renewal-1' }, body: { newRent: 1600 } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'RENEWAL_FINALIZED' }),
    }));
  });

  it('updates pending offer successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'renewal-1', status: 'pending' }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'renewal-1', newRentCents: 160000, newDepositCents: 0, status: 'pending' }]),
        }),
      }),
    });
    const res = mockRes();
    await renewalController.updateRenewalOffer({ params: { id: 'renewal-1' }, body: { newRent: 1600 } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ newRent: 1600 }),
    }));
  });
});

describe('updateRenewalOfferStatus', () => {
  it('returns 400 on validation error', async () => {
    const res = mockRes();
    await renewalController.updateRenewalOfferStatus({ params: { id: 'renewal-1' }, body: { status: 'invalid' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 for invalid transition', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'renewal-1', status: 'accepted' }]);
    const res = mockRes();
    await renewalController.updateRenewalOfferStatus({ params: { id: 'renewal-1' }, body: { status: 'pending' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_STATUS_TRANSITION' }),
    }));
  });

  it('allows pending -> sent transition', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'renewal-1', status: 'pending' }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'renewal-1', status: 'sent', sentAt: new Date(), newRentCents: 150000, newDepositCents: 0 }]),
        }),
      }),
    });
    const res = mockRes();
    await renewalController.updateRenewalOfferStatus({ params: { id: 'renewal-1' }, body: { status: 'sent' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ status: 'sent' }),
    }));
  });

  it('allows sent -> accepted and updates lease', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'renewal-1', status: 'sent', leaseId: 'lease-1', newStartDate: futureStart, newEndDate: futureEnd, newRentCents: 150000, newDepositCents: 0, terms: {} }]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', rentCents: 120000 }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(undefined),
      }),
    }).mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'renewal-1', status: 'accepted', respondedAt: new Date(), newRentCents: 150000, newDepositCents: 0 }]),
        }),
      }),
    });
    const res = mockRes();
    await renewalController.updateRenewalOfferStatus({ params: { id: 'renewal-1' }, body: { status: 'accepted' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ status: 'accepted' }),
    }));
    expect(db.update).toHaveBeenCalledTimes(2);
  });
});

describe('sendRenewalNotification', () => {
  it('returns 404 when offer not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await renewalController.sendRenewalNotification({ params: { id: 'nonexistent' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'RENEWAL_NOT_FOUND' }),
    }));
  });

  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'renewal-1', leaseId: 'lease-1' }]);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await renewalController.sendRenewalNotification({ params: { id: 'renewal-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('queues SMS and emails tenant with phone', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'renewal-1', leaseId: 'lease-1', newRentCents: 150000 }]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', tenantPhone: '+15145551234', tenantEmail: 't@t.com', tenantFirstName: 'Jean', tenantLastName: 'Doe', endDate: new Date() }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(undefined),
      }),
    });
    const res = mockRes();
    await renewalController.sendRenewalNotification({ params: { id: 'renewal-1' }, body: { channel: 'both' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        notifications: expect.arrayContaining([
          expect.objectContaining({ channel: 'sms' }),
          expect.objectContaining({ channel: 'email' }),
        ]),
      }),
    }));
    expect(db.insert).toHaveBeenCalled();
  });
});

describe('getRenewalOffersByLease', () => {
  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await renewalController.getRenewalOffersByLease({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns renewal offers for lease', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1' }]);
    selectChain.orderBy.mockResolvedValueOnce([{ id: 'renewal-1', newRentCents: 150000, newDepositCents: 0, status: 'pending' }]);
    const res = mockRes();
    await renewalController.getRenewalOffersByLease({ params: { id: 'lease-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ newRent: 1500 })]),
    }));
  });
});

describe('getLeasesNeedingRenewal', () => {
  it('returns leases with renewal info', async () => {
    const chain1 = mockSelectChain();
    chain1.from.mockReturnValue(chain1);
    chain1.where.mockResolvedValueOnce([{ id: 'lease-1', unitId: 'unit-1', rentCents: 120000, depositCents: 0, endDate: new Date(Date.now() + 30 * 86400000) }]);
    const chain2 = mockSelectChain();
    chain2.from.mockReturnValue(chain2);
    chain2.where.mockReturnValue(chain2);
    chain2.limit.mockResolvedValueOnce([{ id: 'unit-1', buildingId: 'bld-1' }]);
    const chain3 = mockSelectChain();
    chain3.from.mockReturnValue(chain3);
    chain3.where.mockReturnValue(chain3);
    chain3.limit.mockResolvedValueOnce([{ id: 'bld-1', name: 'Test' }]);
    const chain4 = mockSelectChain();
    chain4.from.mockReturnValue(chain4);
    chain4.where.mockReturnValue(chain4);
    chain4.orderBy.mockReturnValue(chain4);
    chain4.limit.mockResolvedValueOnce([]);
    mockDb.select
      .mockReturnValueOnce(chain1)
      .mockReturnValueOnce(chain2)
      .mockReturnValueOnce(chain3)
      .mockReturnValueOnce(chain4);
    const res = mockRes();
    await renewalController.getLeasesNeedingRenewal({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ daysUntilExpiry: expect.any(Number) })]),
    }));
  });
});
