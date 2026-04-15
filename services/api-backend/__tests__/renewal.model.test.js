/**
 * Renewal Joi validation schema tests
 * Covers: renewalOfferSchema, updateRenewalOfferSchema, renewalOfferStatusSchema,
 *         VALID_RENEWAL_STATUSES, VALID_RENEWAL_CHANNELS, VALID_RENEWAL_TRANSITIONS, RENEWAL_WINDOWS
 */
const {
  renewalOfferSchema,
  updateRenewalOfferSchema,
  renewalOfferStatusSchema,
  VALID_RENEWAL_STATUSES,
  VALID_RENEWAL_CHANNELS,
  VALID_RENEWAL_TRANSITIONS,
  RENEWAL_WINDOWS,
} = require('../src/models/renewal');

// ── Helpers ──
const validOffer = () => ({
  leaseId: '550e8400-e29b-41d4-a716-446655440000',
  newStartDate: '2026-07-01',
  newEndDate: '2027-06-30',
  newRent: 95000,
});

// ── Constants ──
describe('Renewal constants', () => {
  test('VALID_RENEWAL_STATUSES has expected values', () => {
    expect(VALID_RENEWAL_STATUSES).toEqual(['pending', 'sent', 'accepted', 'declined', 'expired']);
  });

  test('VALID_RENEWAL_CHANNELS has expected values', () => {
    expect(VALID_RENEWAL_CHANNELS).toEqual(['sms', 'email', 'both']);
  });

  test('VALID_RENEWAL_TRANSITIONS has correct structure', () => {
    expect(Object.keys(VALID_RENEWAL_TRANSITIONS)).toEqual(['pending', 'sent', 'accepted', 'declined', 'expired']);
    expect(VALID_RENEWAL_TRANSITIONS.accepted).toEqual([]);
    expect(VALID_RENEWAL_TRANSITIONS.declined).toEqual([]);
    expect(VALID_RENEWAL_TRANSITIONS.expired).toEqual([]);
    expect(VALID_RENEWAL_TRANSITIONS.pending).toContain('sent');
    expect(VALID_RENEWAL_TRANSITIONS.sent).toContain('accepted');
    expect(VALID_RENEWAL_TRANSITIONS.sent).toContain('declined');
  });

  test('RENEWAL_WINDOWS has 3 entries with correct days', () => {
    expect(RENEWAL_WINDOWS).toHaveLength(3);
    expect(RENEWAL_WINDOWS.map((w) => w.days)).toEqual([90, 60, 30]);
  });

  test('RENEWAL_WINDOWS have valid channels', () => {
    RENEWAL_WINDOWS.forEach((w) => {
      expect(VALID_RENEWAL_CHANNELS).toContain(w.channel);
    });
  });
});

// ── renewalOfferSchema ──
describe('renewalOfferSchema', () => {
  test('accepts a valid offer with required fields only', () => {
    const { error, value } = renewalOfferSchema.validate(validOffer());
    expect(error).toBeUndefined();
    expect(value.leaseId).toBe('550e8400-e29b-41d4-a716-446655440000');
    expect(value.newRent).toBe(95000);
    expect(value.newDeposit).toBe(0);
    expect(value.terms).toEqual({});
  });

  test('accepts a valid offer with all optional fields', () => {
    const offer = {
      ...validOffer(),
      newDeposit: 50000,
      terms: { pets: false, parking: true },
      notes: 'Offre de renouvellement standard',
    };
    const { error, value } = renewalOfferSchema.validate(offer);
    expect(error).toBeUndefined();
    expect(value.newDeposit).toBe(50000);
    expect(value.terms).toEqual({ pets: false, parking: true });
    expect(value.notes).toBe('Offre de renouvellement standard');
  });

  test('applies defaults for optional fields', () => {
    const { error, value } = renewalOfferSchema.validate(validOffer());
    expect(error).toBeUndefined();
    expect(value.newDeposit).toBe(0);
    expect(value.terms).toEqual({});
  });

  test('accepts null notes', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), notes: null });
    expect(error).toBeUndefined();
  });

  test('accepts empty string notes', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), notes: '' });
    expect(error).toBeUndefined();
  });

  test('rejects missing leaseId', () => {
    const { error } = renewalOfferSchema.validate({
      newStartDate: '2026-07-01',
      newEndDate: '2027-06-30',
      newRent: 95000,
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leaseId');
  });

  test('rejects invalid UUID leaseId', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), leaseId: 'not-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leaseId');
  });

  test('rejects missing newStartDate', () => {
    const { error } = renewalOfferSchema.validate({
      leaseId: '550e8400-e29b-41d4-a716-446655440000',
      newEndDate: '2027-06-30',
      newRent: 95000,
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newStartDate');
  });

  test('rejects missing newEndDate', () => {
    const { error } = renewalOfferSchema.validate({
      leaseId: '550e8400-e29b-41d4-a716-446655440000',
      newStartDate: '2026-07-01',
      newRent: 95000,
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newEndDate');
  });

  test('rejects newEndDate before newStartDate', () => {
    const { error } = renewalOfferSchema.validate({
      ...validOffer(),
      newStartDate: '2027-06-30',
      newEndDate: '2026-07-01',
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newEndDate');
  });

  test('rejects non-ISO newStartDate', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newStartDate: 'not-a-date' });
    expect(error).toBeDefined();
  });

  test('rejects non-ISO newEndDate', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newEndDate: 'not-a-date' });
    expect(error).toBeDefined();
  });

  test('rejects missing newRent', () => {
    const { error } = renewalOfferSchema.validate({
      leaseId: '550e8400-e29b-41d4-a716-446655440000',
      newStartDate: '2026-07-01',
      newEndDate: '2027-06-30',
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('newRent');
  });

  test('rejects zero newRent', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newRent: 0 });
    expect(error).toBeDefined();
  });

  test('rejects negative newRent', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newRent: -100 });
    expect(error).toBeDefined();
  });

  test('rejects newRent exceeding max', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newRent: 1000001 });
    expect(error).toBeDefined();
  });

  test('accepts newRent at max boundary', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newRent: 1000000 });
    expect(error).toBeUndefined();
  });

  test('rejects negative newDeposit', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newDeposit: -1 });
    expect(error).toBeDefined();
  });

  test('rejects non-integer newDeposit', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newDeposit: 1.5 });
    expect(error).toBeDefined();
  });

  test('accepts zero newDeposit', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newDeposit: 0 });
    expect(error).toBeUndefined();
  });

  test('rejects newDeposit exceeding max (200000)', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newDeposit: 200001 });
    expect(error).toBeDefined();
  });

  test('accepts newDeposit at max boundary (200000)', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), newDeposit: 200000 });
    expect(error).toBeUndefined();
  });

  test('rejects notes exceeding 2000 chars', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), notes: 'x'.repeat(2001) });
    expect(error).toBeDefined();
  });

  test('accepts notes at 2000 chars boundary', () => {
    const { error } = renewalOfferSchema.validate({ ...validOffer(), notes: 'x'.repeat(2000) });
    expect(error).toBeUndefined();
  });
});

// ── updateRenewalOfferSchema ──
describe('updateRenewalOfferSchema', () => {
  test('accepts empty update', () => {
    const { error } = updateRenewalOfferSchema.validate({});
    expect(error).toBeUndefined();
  });

  test('accepts newRent update', () => {
    const { error, value } = updateRenewalOfferSchema.validate({ newRent: 100000 });
    expect(error).toBeUndefined();
    expect(value.newRent).toBe(100000);
  });

  test('accepts newDeposit update', () => {
    const { error, value } = updateRenewalOfferSchema.validate({ newDeposit: 30000 });
    expect(error).toBeUndefined();
    expect(value.newDeposit).toBe(30000);
  });

  test('accepts newStartDate update', () => {
    const { error } = updateRenewalOfferSchema.validate({ newStartDate: '2026-08-01' });
    expect(error).toBeUndefined();
  });

  test('accepts newEndDate update', () => {
    const { error } = updateRenewalOfferSchema.validate({ newEndDate: '2027-07-31' });
    expect(error).toBeUndefined();
  });

  test('accepts terms update', () => {
    const { error, value } = updateRenewalOfferSchema.validate({ terms: { parking: true } });
    expect(error).toBeUndefined();
    expect(value.terms).toEqual({ parking: true });
  });

  test('accepts notes update', () => {
    const { error } = updateRenewalOfferSchema.validate({ notes: 'Updated terms' });
    expect(error).toBeUndefined();
  });

  test('accepts null notes', () => {
    const { error } = updateRenewalOfferSchema.validate({ notes: null });
    expect(error).toBeUndefined();
  });

  test('rejects zero newRent', () => {
    const { error } = updateRenewalOfferSchema.validate({ newRent: 0 });
    expect(error).toBeDefined();
  });

  test('rejects negative newRent', () => {
    const { error } = updateRenewalOfferSchema.validate({ newRent: -100 });
    expect(error).toBeDefined();
  });

  test('rejects newRent exceeding max', () => {
    const { error } = updateRenewalOfferSchema.validate({ newRent: 1000001 });
    expect(error).toBeDefined();
  });

  test('rejects negative newDeposit', () => {
    const { error } = updateRenewalOfferSchema.validate({ newDeposit: -1 });
    expect(error).toBeDefined();
  });

  test('rejects notes exceeding 2000 chars', () => {
    const { error } = updateRenewalOfferSchema.validate({ notes: 'x'.repeat(2001) });
    expect(error).toBeDefined();
  });

  test('rejects non-ISO newStartDate', () => {
    const { error } = updateRenewalOfferSchema.validate({ newStartDate: 'bad' });
    expect(error).toBeDefined();
  });

  test('rejects non-ISO newEndDate', () => {
    const { error } = updateRenewalOfferSchema.validate({ newEndDate: 'bad' });
    expect(error).toBeDefined();
  });
});

// ── renewalOfferStatusSchema ──
describe('renewalOfferStatusSchema', () => {
  test('accepts each valid status', () => {
    VALID_RENEWAL_STATUSES.forEach((status) => {
      const { error } = renewalOfferStatusSchema.validate({ status });
      expect(error).toBeUndefined();
    });
  });

  test('rejects missing status', () => {
    const { error } = renewalOfferStatusSchema.validate({});
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  test('rejects invalid status', () => {
    const { error } = renewalOfferStatusSchema.validate({ status: 'counter_offered' });
    expect(error).toBeDefined();
  });

  test('accepts optional tenantResponse', () => {
    const { error, value } = renewalOfferStatusSchema.validate({
      status: 'accepted',
      tenantResponse: 'J\'accepte les nouvelles conditions',
    });
    expect(error).toBeUndefined();
    expect(value.tenantResponse).toBe('J\'accepte les nouvelles conditions');
  });

  test('accepts null tenantResponse', () => {
    const { error } = renewalOfferStatusSchema.validate({ status: 'declined', tenantResponse: null });
    expect(error).toBeUndefined();
  });

  test('accepts empty string tenantResponse', () => {
    const { error } = renewalOfferStatusSchema.validate({ status: 'sent', tenantResponse: '' });
    expect(error).toBeUndefined();
  });

  test('rejects tenantResponse exceeding 2000 chars', () => {
    const { error } = renewalOfferStatusSchema.validate({ status: 'declined', tenantResponse: 'x'.repeat(2001) });
    expect(error).toBeDefined();
  });
});
