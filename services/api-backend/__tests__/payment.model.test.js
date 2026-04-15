const {
  paymentSchema,
  updatePaymentSchema,
  paymentStatusSchema,
  VALID_PAYMENT_STATUSES,
  VALID_PAYMENT_METHODS,
  VALID_STATUS_TRANSITIONS,
} = require('../src/models/payment');

describe('paymentSchema', () => {
  const validPayload = {
    leaseId: '550e8400-e29b-41d4-a716-446655440000',
    amount: 1200,
    dueDate: '2026-06-01',
  };

  it('validates a valid payment', () => {
    const { error } = paymentSchema.validate(validPayload);
    expect(error).toBeUndefined();
  });

  it('requires leaseId', () => {
    const { error } = paymentSchema.validate({ ...validPayload, leaseId: undefined });
    expect(error).toBeDefined();
  });

  it('requires leaseId to be a UUID', () => {
    const { error } = paymentSchema.validate({ ...validPayload, leaseId: 'not-a-uuid' });
    expect(error).toBeDefined();
  });

  it('requires amount', () => {
    const { error } = paymentSchema.validate({ ...validPayload, amount: undefined });
    expect(error).toBeDefined();
  });

  it('rejects zero amount', () => {
    const { error } = paymentSchema.validate({ ...validPayload, amount: 0 });
    expect(error).toBeDefined();
  });

  it('rejects negative amount', () => {
    const { error } = paymentSchema.validate({ ...validPayload, amount: -100 });
    expect(error).toBeDefined();
  });

  it('rejects amount over 1000000', () => {
    const { error } = paymentSchema.validate({ ...validPayload, amount: 1000001 });
    expect(error).toBeDefined();
  });

  it('requires dueDate', () => {
    const { error } = paymentSchema.validate({ ...validPayload, dueDate: undefined });
    expect(error).toBeDefined();
  });

  it('accepts valid method', () => {
    const { error } = paymentSchema.validate({ ...validPayload, method: 'interac' });
    expect(error).toBeUndefined();
  });

  it('rejects invalid method', () => {
    const { error } = paymentSchema.validate({ ...validPayload, method: 'bitcoin' });
    expect(error).toBeDefined();
  });

  it('accepts null method', () => {
    const { error } = paymentSchema.validate({ ...validPayload, method: null });
    expect(error).toBeUndefined();
  });

  it('accepts reference and notes', () => {
    const { error } = paymentSchema.validate({
      ...validPayload,
      reference: 'CHK-001',
      notes: 'Monthly rent',
    });
    expect(error).toBeUndefined();
  });

  it('rejects reference over 200 chars', () => {
    const { error } = paymentSchema.validate({ ...validPayload, reference: 'x'.repeat(201) });
    expect(error).toBeDefined();
  });

  it('rejects notes over 1000 chars', () => {
    const { error } = paymentSchema.validate({ ...validPayload, notes: 'x'.repeat(1001) });
    expect(error).toBeDefined();
  });
});

describe('updatePaymentSchema', () => {
  it('allows empty body (no fields required)', () => {
    const { error } = updatePaymentSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('validates amount when provided', () => {
    const { error } = updatePaymentSchema.validate({ amount: 1500 });
    expect(error).toBeUndefined();
  });

  it('rejects negative amount', () => {
    const { error } = updatePaymentSchema.validate({ amount: -10 });
    expect(error).toBeDefined();
  });

  it('allows paidDate as ISO date', () => {
    const { error } = updatePaymentSchema.validate({ paidDate: '2026-05-15' });
    expect(error).toBeUndefined();
  });

  it('allows null paidDate', () => {
    const { error } = updatePaymentSchema.validate({ paidDate: null });
    expect(error).toBeUndefined();
  });

  it('accepts valid lateFeeCents', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: 500 });
    expect(error).toBeUndefined();
  });

  it('rejects negative lateFeeCents', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: -1 });
    expect(error).toBeDefined();
  });
});

describe('paymentStatusSchema', () => {
  it('validates all valid statuses', () => {
    for (const status of VALID_PAYMENT_STATUSES) {
      const { error } = paymentStatusSchema.validate({ status });
      expect(error).toBeUndefined();
    }
  });

  it('rejects invalid status', () => {
    const { error } = paymentStatusSchema.validate({ status: 'refunded' });
    expect(error).toBeDefined();
  });

  it('requires status', () => {
    const { error } = paymentStatusSchema.validate({});
    expect(error).toBeDefined();
  });
});

describe('VALID_PAYMENT_STATUSES', () => {
  it('contains expected statuses', () => {
    expect(VALID_PAYMENT_STATUSES).toEqual(
      expect.arrayContaining(['pending', 'paid', 'late', 'partial']),
    );
  });
});

describe('VALID_PAYMENT_METHODS', () => {
  it('contains expected methods', () => {
    expect(VALID_PAYMENT_METHODS).toEqual(
      expect.arrayContaining(['check', 'transfer', 'cash', 'interac', 'auto_debit']),
    );
  });
});

describe('VALID_STATUS_TRANSITIONS', () => {
  it('allows pending -> paid', () => {
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('paid');
  });

  it('allows pending -> late', () => {
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('late');
  });

  it('allows pending -> partial', () => {
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('partial');
  });

  it('allows late -> paid', () => {
    expect(VALID_STATUS_TRANSITIONS.late).toContain('paid');
  });

  it('allows partial -> paid', () => {
    expect(VALID_STATUS_TRANSITIONS.partial).toContain('paid');
  });

  it('does not allow paid -> any', () => {
    expect(VALID_STATUS_TRANSITIONS.paid).toEqual([]);
  });

  it('every target status is valid', () => {
    for (const [, targets] of Object.entries(VALID_STATUS_TRANSITIONS)) {
      for (const target of targets) {
        expect(VALID_PAYMENT_STATUSES).toContain(target);
      }
    }
  });
});
