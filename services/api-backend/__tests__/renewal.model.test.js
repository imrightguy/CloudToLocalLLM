const {
  renewalOfferSchema,
  updateRenewalOfferSchema,
  renewalOfferStatusSchema,
  VALID_RENEWAL_STATUSES,
  VALID_RENEWAL_CHANNELS,
  VALID_RENEWAL_TRANSITIONS,
  RENEWAL_WINDOWS,
} = require('../src/models/renewal');

const validPayload = {
  leaseId: '550e8400-e29b-41d4-a716-446655440000',
  newStartDate: '2027-06-01',
  newEndDate: '2028-05-31',
  newRent: 1500,
};

describe('renewalOfferSchema', () => {
  it('validates a valid renewal offer', () => {
    const { error } = renewalOfferSchema.validate(validPayload);
    expect(error).toBeUndefined();
  });

  it('requires leaseId', () => {
    const { error } = renewalOfferSchema.validate({ ...validPayload, leaseId: undefined });
    expect(error).toBeDefined();
  });

  it('requires leaseId to be UUID', () => {
    const { error } = renewalOfferSchema.validate({ ...validPayload, leaseId: 'bad' });
    expect(error).toBeDefined();
  });

  it('requires newRent', () => {
    const { error } = renewalOfferSchema.validate({ ...validPayload, newRent: undefined });
    expect(error).toBeDefined();
  });

  it('rejects zero newRent', () => {
    const { error } = renewalOfferSchema.validate({ ...validPayload, newRent: 0 });
    expect(error).toBeDefined();
  });

  it('requires newEndDate > newStartDate', () => {
    const { error } = renewalOfferSchema.validate({ ...validPayload, newEndDate: '2020-01-01' });
    expect(error).toBeDefined();
  });

  it('accepts optional newDeposit and terms', () => {
    const { error } = renewalOfferSchema.validate({
      ...validPayload,
      newDeposit: 500,
      terms: { parking: true },
    });
    expect(error).toBeUndefined();
  });

  it('accepts notes', () => {
    const { error } = renewalOfferSchema.validate({ ...validPayload, notes: 'Rent increase due to market' });
    expect(error).toBeUndefined();
  });

  it('rejects notes over 2000 chars', () => {
    const { error } = renewalOfferSchema.validate({ ...validPayload, notes: 'x'.repeat(2001) });
    expect(error).toBeDefined();
  });
});

describe('updateRenewalOfferSchema', () => {
  it('allows empty body', () => {
    const { error } = updateRenewalOfferSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('validates newRent when provided', () => {
    const { error } = updateRenewalOfferSchema.validate({ newRent: 1600 });
    expect(error).toBeUndefined();
  });

  it('rejects negative newRent', () => {
    const { error } = updateRenewalOfferSchema.validate({ newRent: -10 });
    expect(error).toBeDefined();
  });
});

describe('renewalOfferStatusSchema', () => {
  it('validates all valid statuses', () => {
    for (const status of VALID_RENEWAL_STATUSES) {
      const { error } = renewalOfferStatusSchema.validate({ status });
      expect(error).toBeUndefined();
    }
  });

  it('rejects invalid status', () => {
    const { error } = renewalOfferStatusSchema.validate({ status: 'cancelled' });
    expect(error).toBeDefined();
  });

  it('requires status', () => {
    const { error } = renewalOfferStatusSchema.validate({});
    expect(error).toBeDefined();
  });

  it('accepts optional tenantResponse', () => {
    const { error } = renewalOfferStatusSchema.validate({ status: 'accepted', tenantResponse: 'Looking forward to another year!' });
    expect(error).toBeUndefined();
  });
});

describe('VALID_RENEWAL_STATUSES', () => {
  it('contains expected statuses', () => {
    expect(VALID_RENEWAL_STATUSES).toEqual(
      expect.arrayContaining(['pending', 'sent', 'accepted', 'declined', 'expired']),
    );
  });
});

describe('VALID_RENEWAL_TRANSITIONS', () => {
  it('allows pending -> sent', () => {
    expect(VALID_RENEWAL_TRANSITIONS.pending).toContain('sent');
  });

  it('allows pending -> expired', () => {
    expect(VALID_RENEWAL_TRANSITIONS.pending).toContain('expired');
  });

  it('allows sent -> accepted', () => {
    expect(VALID_RENEWAL_TRANSITIONS.sent).toContain('accepted');
  });

  it('allows sent -> declined', () => {
    expect(VALID_RENEWAL_TRANSITIONS.sent).toContain('declined');
  });

  it('does not allow transitions from accepted', () => {
    expect(VALID_RENEWAL_TRANSITIONS.accepted).toEqual([]);
  });

  it('does not allow transitions from declined', () => {
    expect(VALID_RENEWAL_TRANSITIONS.declined).toEqual([]);
  });

  it('every target status is valid', () => {
    for (const [, targets] of Object.entries(VALID_RENEWAL_TRANSITIONS)) {
      for (const target of targets) {
        expect(VALID_RENEWAL_STATUSES).toContain(target);
      }
    }
  });
});

describe('RENEWAL_WINDOWS', () => {
  it('has 30, 60, 90 day windows', () => {
    const days = RENEWAL_WINDOWS.map(w => w.days);
    expect(days).toEqual([90, 60, 30]);
  });

  it('90-day uses email channel', () => {
    expect(RENEWAL_WINDOWS[0].channel).toBe('email');
  });

  it('60-day uses email channel', () => {
    expect(RENEWAL_WINDOWS[1].channel).toBe('email');
  });

  it('30-day uses both channel', () => {
    expect(RENEWAL_WINDOWS[2].channel).toBe('both');
  });
});

describe('VALID_RENEWAL_CHANNELS', () => {
  it('contains sms, email, both', () => {
    expect(VALID_RENEWAL_CHANNELS).toEqual(['sms', 'email', 'both']);
  });
});
