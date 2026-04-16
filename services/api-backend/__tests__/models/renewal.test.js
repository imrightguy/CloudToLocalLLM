const {
  renewalOfferSchema,
  updateRenewalOfferSchema,
  renewalOfferStatusSchema,
  VALID_RENEWAL_STATUSES,
  VALID_RENEWAL_CHANNELS,
  VALID_RENEWAL_TRANSITIONS,
  RENEWAL_WINDOWS,
} = require('../../src/models/renewal');

describe('renewalOfferSchema', () => {
  const validRenewal = {
    leaseId: '550e8400-e29b-41d4-a716-446655440000',
    newStartDate: '2027-07-01',
    newEndDate: '2028-06-30',
    newRent: 90000,
  };

  it('validates a minimal valid renewal offer', () => {
    const { error, value } = renewalOfferSchema.validate(validRenewal);
    expect(error).toBeUndefined();
    expect(value.leaseId).toBe(validRenewal.leaseId);
    expect(value.newRent).toBe(90000);
    expect(value.newDeposit).toBe(0);
    expect(value.terms).toEqual({});
  });

  it('validates a full renewal offer with all optional fields', () => {
    const full = {
      ...validRenewal,
      newDeposit: 90000,
      terms: { petsAllowed: true, parkingIncluded: false },
      notes: 'Augmentation de loyer de 5%',
    };
    const { error, value } = renewalOfferSchema.validate(full);
    expect(error).toBeUndefined();
    expect(value.newDeposit).toBe(90000);
    expect(value.terms.petsAllowed).toBe(true);
    expect(value.notes).toBe('Augmentation de loyer de 5%');
  });

  it('rejects missing leaseId', () => {
    const { error } = renewalOfferSchema.validate({
      newStartDate: '2027-07-01',
      newEndDate: '2028-06-30',
      newRent: 90000,
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leaseId');
  });

  it('rejects invalid leaseId', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, leaseId: 'not-a-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leaseId');
  });

  it('rejects missing newStartDate', () => {
    const { error } = renewalOfferSchema.validate({
      ...validRenewal,
      newStartDate: undefined,
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newStartDate');
  });

  it('rejects invalid newStartDate', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newStartDate: 'not-a-date' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newStartDate');
  });

  it('rejects missing newEndDate', () => {
    const { error } = renewalOfferSchema.validate({
      ...validRenewal,
      newEndDate: undefined,
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newEndDate');
  });

  it('rejects invalid newEndDate', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newEndDate: 'not-a-date' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newEndDate');
  });

  it('rejects newEndDate before newStartDate', () => {
    const { error } = renewalOfferSchema.validate({
      ...validRenewal,
      newStartDate: '2028-01-01',
      newEndDate: '2027-12-31',
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newEndDate');
  });

  it('rejects newEndDate equal to newStartDate', () => {
    const { error } = renewalOfferSchema.validate({
      ...validRenewal,
      newStartDate: '2027-07-01',
      newEndDate: '2027-07-01',
    });
    expect(error).toBeDefined();
  });

  it('rejects missing newRent', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newRent: undefined });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newRent');
  });

  it('rejects non-positive newRent', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newRent: 0 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newRent');
  });

  it('rejects negative newRent', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newRent: -100 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newRent');
  });

  it('rejects newRent over 1000000', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newRent: 1000001 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newRent');
  });

  it('defaults newDeposit to 0', () => {
    const { value } = renewalOfferSchema.validate(validRenewal);
    expect(value.newDeposit).toBe(0);
  });

  it('accepts valid newDeposit', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newDeposit: 90000 });
    expect(error).toBeUndefined();
  });

  it('rejects negative newDeposit', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newDeposit: -1 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newDeposit');
  });

  it('rejects newDeposit over 200000', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newDeposit: 200001 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newDeposit');
  });

  it('rejects non-integer newDeposit', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, newDeposit: 100.50 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newDeposit');
  });

  it('allows null notes', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, notes: null });
    expect(error).toBeUndefined();
  });

  it('allows empty string notes', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, notes: '' });
    expect(error).toBeUndefined();
  });

  it('rejects notes over 2000 characters', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, notes: 'N'.repeat(2001) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('notes');
  });

  it('defaults terms to empty object', () => {
    const { value } = renewalOfferSchema.validate(validRenewal);
    expect(value.terms).toEqual({});
  });

  it('accepts terms as object', () => {
    const { error } = renewalOfferSchema.validate({
      ...validRenewal,
      terms: { parkingIncluded: true },
    });
    expect(error).toBeUndefined();
  });

  it('rejects terms as non-object', () => {
    const { error } = renewalOfferSchema.validate({ ...validRenewal, terms: 'not-an-object' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('terms');
  });
});

describe('updateRenewalOfferSchema', () => {
  it('validates empty object', () => {
    const { error } = updateRenewalOfferSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('validates partial update with just newRent', () => {
    const { error, value } = updateRenewalOfferSchema.validate({ newRent: 95000 });
    expect(error).toBeUndefined();
    expect(value.newRent).toBe(95000);
  });

  it('validates partial update with dates and terms', () => {
    const { error } = updateRenewalOfferSchema.validate({
      newStartDate: '2027-08-01',
      newEndDate: '2028-07-31',
      terms: { petsAllowed: false },
    });
    expect(error).toBeUndefined();
  });

  it('still validates newRent is positive', () => {
    const { error } = updateRenewalOfferSchema.validate({ newRent: 0 });
    expect(error).toBeDefined();
  });

  it('still validates newRent max', () => {
    const { error } = updateRenewalOfferSchema.validate({ newRent: 1000001 });
    expect(error).toBeDefined();
  });

  it('still validates newDeposit min', () => {
    const { error } = updateRenewalOfferSchema.validate({ newDeposit: -1 });
    expect(error).toBeDefined();
  });

  it('still validates newDeposit max', () => {
    const { error } = updateRenewalOfferSchema.validate({ newDeposit: 200001 });
    expect(error).toBeDefined();
  });

  it('still validates newDeposit is integer', () => {
    const { error } = updateRenewalOfferSchema.validate({ newDeposit: 100.50 });
    expect(error).toBeDefined();
  });

  it('validates newStartDate format', () => {
    const { error } = updateRenewalOfferSchema.validate({ newStartDate: 'not-a-date' });
    expect(error).toBeDefined();
  });

  it('validates newEndDate format', () => {
    const { error } = updateRenewalOfferSchema.validate({ newEndDate: 'not-a-date' });
    expect(error).toBeDefined();
  });

  it('allows null notes', () => {
    const { error } = updateRenewalOfferSchema.validate({ notes: null });
    expect(error).toBeUndefined();
  });

  it('allows empty string notes', () => {
    const { error } = updateRenewalOfferSchema.validate({ notes: '' });
    expect(error).toBeUndefined();
  });

  it('still validates notes max length', () => {
    const { error } = updateRenewalOfferSchema.validate({ notes: 'N'.repeat(2001) });
    expect(error).toBeDefined();
  });

  it('allows updating terms', () => {
    const { error } = updateRenewalOfferSchema.validate({ terms: { petsAllowed: true } });
    expect(error).toBeUndefined();
  });

  it('rejects terms as non-object', () => {
    const { error } = updateRenewalOfferSchema.validate({ terms: 'bad' });
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
    expect(error.details[0].path).toContain('status');
  });

  it('rejects missing status', () => {
    const { error } = renewalOfferStatusSchema.validate({});
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  it('allows tenantResponse with status', () => {
    const { error } = renewalOfferStatusSchema.validate({
      status: 'accepted',
      tenantResponse: "J'accepte l'offre",
    });
    expect(error).toBeUndefined();
  });

  it('allows null tenantResponse', () => {
    const { error } = renewalOfferStatusSchema.validate({
      status: 'accepted',
      tenantResponse: null,
    });
    expect(error).toBeUndefined();
  });

  it('allows empty string tenantResponse', () => {
    const { error } = renewalOfferStatusSchema.validate({
      status: 'declined',
      tenantResponse: '',
    });
    expect(error).toBeUndefined();
  });

  it('rejects tenantResponse over 2000 characters', () => {
    const { error } = renewalOfferStatusSchema.validate({
      status: 'accepted',
      tenantResponse: 'X'.repeat(2001),
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantResponse');
  });
});

describe('VALID_RENEWAL_TRANSITIONS', () => {
  it('contains all valid statuses as keys', () => {
    for (const status of VALID_RENEWAL_STATUSES) {
      expect(VALID_RENEWAL_TRANSITIONS).toHaveProperty(status);
    }
  });

  it('allows pending → sent', () => {
    expect(VALID_RENEWAL_TRANSITIONS.pending).toContain('sent');
  });

  it('allows pending → expired', () => {
    expect(VALID_RENEWAL_TRANSITIONS.pending).toContain('expired');
  });

  it('allows sent → accepted', () => {
    expect(VALID_RENEWAL_TRANSITIONS.sent).toContain('accepted');
  });

  it('allows sent → declined', () => {
    expect(VALID_RENEWAL_TRANSITIONS.sent).toContain('declined');
  });

  it('allows sent → expired', () => {
    expect(VALID_RENEWAL_TRANSITIONS.sent).toContain('expired');
  });

  it('accepted has no valid transitions', () => {
    expect(VALID_RENEWAL_TRANSITIONS.accepted).toEqual([]);
  });

  it('declined has no valid transitions', () => {
    expect(VALID_RENEWAL_TRANSITIONS.declined).toEqual([]);
  });

  it('expired has no valid transitions', () => {
    expect(VALID_RENEWAL_TRANSITIONS.expired).toEqual([]);
  });
});

describe('RENEWAL_WINDOWS', () => {
  it('has 3 defined windows', () => {
    expect(RENEWAL_WINDOWS).toHaveLength(3);
  });

  it('has 90-day email reminder', () => {
    expect(RENEWAL_WINDOWS[0]).toEqual({
      days: 90,
      label: '90-day reminder',
      channel: 'email',
    });
  });

  it('has 60-day email reminder', () => {
    expect(RENEWAL_WINDOWS[1]).toEqual({
      days: 60,
      label: '60-day reminder',
      channel: 'email',
    });
  });

  it('has 30-day both reminder', () => {
    expect(RENEWAL_WINDOWS[2]).toEqual({
      days: 30,
      label: '30-day reminder',
      channel: 'both',
    });
  });
});

describe('VALID_RENEWAL_CHANNELS', () => {
  it('includes sms, email, and both', () => {
    expect(VALID_RENEWAL_CHANNELS).toContain('sms');
    expect(VALID_RENEWAL_CHANNELS).toContain('email');
    expect(VALID_RENEWAL_CHANNELS).toContain('both');
  });
});
