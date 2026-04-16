const {
  paymentSchema,
  updatePaymentSchema,
  paymentStatusSchema,
  VALID_PAYMENT_STATUSES,
  VALID_PAYMENT_METHODS,
  VALID_STATUS_TRANSITIONS,
} = require('../../src/models/payment');

describe('paymentSchema', () => {
  const validPayment = {
    leaseId: '550e8400-e29b-41d4-a716-446655440000',
    amount: 85000,
    dueDate: '2026-07-01',
  };

  it('validates a minimal valid payment', () => {
    const { error, value } = paymentSchema.validate(validPayment);
    expect(error).toBeUndefined();
    expect(value.leaseId).toBe(validPayment.leaseId);
    expect(value.amount).toBe(85000);
    expect(value.dueDate).toEqual(new Date('2026-07-01T00:00:00.000Z'));
  });

  it('validates a full payment with all optional fields', () => {
    const full = {
      ...validPayment,
      method: 'interac',
      reference: 'REF-2026-001',
      notes: 'Juillet 2026',
    };
    const { error, value } = paymentSchema.validate(full);
    expect(error).toBeUndefined();
    expect(value.method).toBe('interac');
    expect(value.reference).toBe('REF-2026-001');
    expect(value.notes).toBe('Juillet 2026');
  });

  it('rejects missing leaseId', () => {
    const { error } = paymentSchema.validate({ amount: 85000, dueDate: '2026-07-01' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leaseId');
  });

  it('rejects invalid leaseId', () => {
    const { error } = paymentSchema.validate({ ...validPayment, leaseId: 'not-a-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leaseId');
  });

  it('rejects missing amount', () => {
    const { error } = paymentSchema.validate({ leaseId: validPayment.leaseId, dueDate: '2026-07-01' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  it('rejects non-positive amount', () => {
    const { error } = paymentSchema.validate({ ...validPayment, amount: 0 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  it('rejects negative amount', () => {
    const { error } = paymentSchema.validate({ ...validPayment, amount: -100 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  it('rejects amount over 1000000', () => {
    const { error } = paymentSchema.validate({ ...validPayment, amount: 1000001 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  it('rejects non-number amount', () => {
    const { error } = paymentSchema.validate({ ...validPayment, amount: 'not-a-number' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  it('rejects missing dueDate', () => {
    const { error } = paymentSchema.validate({ leaseId: validPayment.leaseId, amount: 85000 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('dueDate');
  });

  it('rejects invalid dueDate', () => {
    const { error } = paymentSchema.validate({ ...validPayment, dueDate: 'not-a-date' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('dueDate');
  });

  it('accepts all valid payment methods', () => {
    for (const method of VALID_PAYMENT_METHODS) {
      const { error } = paymentSchema.validate({ ...validPayment, method });
      expect(error).toBeUndefined();
    }
  });

  it('rejects invalid payment method', () => {
    const { error } = paymentSchema.validate({ ...validPayment, method: 'crypto' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('method');
  });

  it('allows null method', () => {
    const { error } = paymentSchema.validate({ ...validPayment, method: null });
    expect(error).toBeUndefined();
  });

  it('rejects empty string method', () => {
    const { error } = paymentSchema.validate({ ...validPayment, method: '' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('method');
  });

  it('allows null reference', () => {
    const { error } = paymentSchema.validate({ ...validPayment, reference: null });
    expect(error).toBeUndefined();
  });

  it('allows empty string reference', () => {
    const { error } = paymentSchema.validate({ ...validPayment, reference: '' });
    expect(error).toBeUndefined();
  });

  it('rejects reference over 200 characters', () => {
    const { error } = paymentSchema.validate({ ...validPayment, reference: 'R'.repeat(201) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('reference');
  });

  it('allows null notes', () => {
    const { error } = paymentSchema.validate({ ...validPayment, notes: null });
    expect(error).toBeUndefined();
  });

  it('allows empty string notes', () => {
    const { error } = paymentSchema.validate({ ...validPayment, notes: '' });
    expect(error).toBeUndefined();
  });

  it('rejects notes over 1000 characters', () => {
    const { error } = paymentSchema.validate({ ...validPayment, notes: 'N'.repeat(1001) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('notes');
  });
});

describe('updatePaymentSchema', () => {
  it('validates empty object', () => {
    const { error } = updatePaymentSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('validates partial update with just amount', () => {
    const { error, value } = updatePaymentSchema.validate({ amount: 90000 });
    expect(error).toBeUndefined();
    expect(value.amount).toBe(90000);
  });

  it('validates partial update with method and reference', () => {
    const { error } = updatePaymentSchema.validate({
      method: 'check',
      reference: 'CHK-001',
    });
    expect(error).toBeUndefined();
  });

  it('still validates amount is positive', () => {
    const { error } = updatePaymentSchema.validate({ amount: 0 });
    expect(error).toBeDefined();
  });

  it('still validates amount max', () => {
    const { error } = updatePaymentSchema.validate({ amount: 1000001 });
    expect(error).toBeDefined();
  });

  it('still validates method enum', () => {
    const { error } = updatePaymentSchema.validate({ method: 'bitcoin' });
    expect(error).toBeDefined();
  });

  it('validates paidDate as ISO date', () => {
    const { error } = updatePaymentSchema.validate({ paidDate: 'not-a-date' });
    expect(error).toBeDefined();
  });

  it('allows null paidDate', () => {
    const { error } = updatePaymentSchema.validate({ paidDate: null });
    expect(error).toBeUndefined();
  });

  it('validates lateFeeCents as integer', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: 50.5 });
    expect(error).toBeDefined();
  });

  it('validates lateFeeCents min 0', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: -1 });
    expect(error).toBeDefined();
  });

  it('allows lateFeeCents of 0', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: 0 });
    expect(error).toBeUndefined();
  });

  it('allows valid lateFeeCents', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: 2500 });
    expect(error).toBeUndefined();
  });

  it('still validates reference max length', () => {
    const { error } = updatePaymentSchema.validate({ reference: 'R'.repeat(201) });
    expect(error).toBeDefined();
  });

  it('still validates notes max length', () => {
    const { error } = updatePaymentSchema.validate({ notes: 'N'.repeat(1001) });
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
    const { error } = paymentStatusSchema.validate({ status: 'cancelled' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  it('rejects missing status', () => {
    const { error } = paymentStatusSchema.validate({});
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  it('rejects empty status', () => {
    const { error } = paymentStatusSchema.validate({ status: '' });
    expect(error).toBeDefined();
  });
});

describe('VALID_STATUS_TRANSITIONS', () => {
  it('contains all valid statuses as keys', () => {
    for (const status of VALID_PAYMENT_STATUSES) {
      expect(VALID_STATUS_TRANSITIONS).toHaveProperty(status);
    }
  });

  it('allows pending → paid', () => {
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('paid');
  });

  it('allows pending → late', () => {
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('late');
  });

  it('allows pending → partial', () => {
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('partial');
  });

  it('allows late → paid', () => {
    expect(VALID_STATUS_TRANSITIONS.late).toContain('paid');
  });

  it('allows late → partial', () => {
    expect(VALID_STATUS_TRANSITIONS.late).toContain('partial');
  });

  it('allows partial → paid', () => {
    expect(VALID_STATUS_TRANSITIONS.partial).toContain('paid');
  });

  it('paid has no valid transitions', () => {
    expect(VALID_STATUS_TRANSITIONS.paid).toEqual([]);
  });
});
