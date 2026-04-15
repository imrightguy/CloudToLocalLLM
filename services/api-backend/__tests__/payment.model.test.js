/**
 * Payment Joi validation schema tests
 * Covers: paymentSchema, updatePaymentSchema, paymentStatusSchema,
 *         VALID_PAYMENT_STATUSES, VALID_PAYMENT_METHODS, VALID_STATUS_TRANSITIONS
 */
const {
  paymentSchema,
  updatePaymentSchema,
  paymentStatusSchema,
  VALID_PAYMENT_STATUSES,
  VALID_PAYMENT_METHODS,
  VALID_STATUS_TRANSITIONS,
} = require('../src/models/payment');

// ── Helpers ──
const validPayment = () => ({
  leaseId: '550e8400-e29b-41d4-a716-446655440000',
  amount: 85000,
  dueDate: '2026-06-01',
});

// ── Constants ──
describe('Payment constants', () => {
  test('VALID_PAYMENT_STATUSES has expected values', () => {
    expect(VALID_PAYMENT_STATUSES).toEqual(['pending', 'paid', 'late', 'partial']);
  });

  test('VALID_PAYMENT_METHODS has expected values', () => {
    expect(VALID_PAYMENT_METHODS).toEqual(['check', 'transfer', 'cash', 'interac', 'auto_debit']);
  });

  test('VALID_STATUS_TRANSITIONS has correct structure', () => {
    expect(Object.keys(VALID_STATUS_TRANSITIONS)).toEqual(['pending', 'late', 'partial', 'paid']);
    expect(VALID_STATUS_TRANSITIONS.paid).toEqual([]);
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('paid');
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('late');
    expect(VALID_STATUS_TRANSITIONS.pending).toContain('partial');
  });
});

// ── paymentSchema ──
describe('paymentSchema', () => {
  test('accepts a valid payment with required fields only', () => {
    const { error, value } = paymentSchema.validate(validPayment());
    expect(error).toBeUndefined();
    expect(value.leaseId).toBe('550e8400-e29b-41d4-a716-446655440000');
    expect(value.amount).toBe(85000);
    expect(value.dueDate).toBeDefined();
  });

  test('accepts a valid payment with all optional fields', () => {
    const payment = {
      ...validPayment(),
      method: 'interac',
      reference: 'REF-001',
      notes: 'Paiement via Interac',
    };
    const { error, value } = paymentSchema.validate(payment);
    expect(error).toBeUndefined();
    expect(value.method).toBe('interac');
    expect(value.reference).toBe('REF-001');
    expect(value.notes).toBe('Paiement via Interac');
  });

  test('accepts null method', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), method: null });
    expect(error).toBeUndefined();
  });

  test('accepts null reference', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), reference: null });
    expect(error).toBeUndefined();
  });

  test('accepts empty string reference', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), reference: '' });
    expect(error).toBeUndefined();
  });

  test('accepts null notes', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), notes: null });
    expect(error).toBeUndefined();
  });

  test('accepts empty string notes', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), notes: '' });
    expect(error).toBeUndefined();
  });

  test('accepts each valid payment method', () => {
    VALID_PAYMENT_METHODS.forEach((method) => {
      const { error } = paymentSchema.validate({ ...validPayment(), method });
      expect(error).toBeUndefined();
    });
  });

  test('rejects missing leaseId', () => {
    const { error } = paymentSchema.validate({ amount: 85000, dueDate: '2026-06-01' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leaseId');
  });

  test('rejects invalid UUID leaseId', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), leaseId: 'not-a-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leaseId');
  });

  test('rejects missing amount', () => {
    const { error } = paymentSchema.validate({ leaseId: '550e8400-e29b-41d4-a716-446655440000', dueDate: '2026-06-01' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  test('rejects zero amount', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), amount: 0 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  test('rejects negative amount', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), amount: -100 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  test('rejects amount exceeding max', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), amount: 1000001 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amount');
  });

  test('accepts amount at max boundary (1000000)', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), amount: 1000000 });
    expect(error).toBeUndefined();
  });

  test('rejects missing dueDate', () => {
    const { error } = paymentSchema.validate({ leaseId: '550e8400-e29b-41d4-a716-446655440000', amount: 85000 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('dueDate');
  });

  test('rejects non-ISO dueDate', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), dueDate: 'not-a-date' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('dueDate');
  });

  test('rejects invalid payment method', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), method: 'bitcoin' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('method');
  });

  test('rejects reference exceeding 200 chars', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), reference: 'x'.repeat(201) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('reference');
  });

  test('accepts reference at 200 chars boundary', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), reference: 'x'.repeat(200) });
    expect(error).toBeUndefined();
  });

  test('rejects notes exceeding 1000 chars', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), notes: 'x'.repeat(1001) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('notes');
  });

  test('accepts notes at 1000 chars boundary', () => {
    const { error } = paymentSchema.validate({ ...validPayment(), notes: 'x'.repeat(1000) });
    expect(error).toBeUndefined();
  });
});

// ── updatePaymentSchema ──
describe('updatePaymentSchema', () => {
  test('accepts empty update', () => {
    const { error } = updatePaymentSchema.validate({});
    expect(error).toBeUndefined();
  });

  test('accepts amount update', () => {
    const { error, value } = updatePaymentSchema.validate({ amount: 90000 });
    expect(error).toBeUndefined();
    expect(value.amount).toBe(90000);
  });

  test('accepts paidDate update', () => {
    const { error, value } = updatePaymentSchema.validate({ paidDate: '2026-05-15' });
    expect(error).toBeUndefined();
    expect(value.paidDate).toBeDefined();
  });

  test('accepts null paidDate', () => {
    const { error } = updatePaymentSchema.validate({ paidDate: null });
    expect(error).toBeUndefined();
  });

  test('accepts method update', () => {
    const { error, value } = updatePaymentSchema.validate({ method: 'check' });
    expect(error).toBeUndefined();
    expect(value.method).toBe('check');
  });

  test('accepts null method', () => {
    const { error } = updatePaymentSchema.validate({ method: null });
    expect(error).toBeUndefined();
  });

  test('accepts each valid method', () => {
    VALID_PAYMENT_METHODS.forEach((method) => {
      const { error } = updatePaymentSchema.validate({ method });
      expect(error).toBeUndefined();
    });
  });

  test('accepts reference update', () => {
    const { error } = updatePaymentSchema.validate({ reference: 'REF-002' });
    expect(error).toBeUndefined();
  });

  test('accepts null reference', () => {
    const { error } = updatePaymentSchema.validate({ reference: null });
    expect(error).toBeUndefined();
  });

  test('accepts notes update', () => {
    const { error } = updatePaymentSchema.validate({ notes: 'Updated' });
    expect(error).toBeUndefined();
  });

  test('accepts lateFeeCents update', () => {
    const { error, value } = updatePaymentSchema.validate({ lateFeeCents: 2500 });
    expect(error).toBeUndefined();
    expect(value.lateFeeCents).toBe(2500);
  });

  test('accepts zero lateFeeCents', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: 0 });
    expect(error).toBeUndefined();
  });

  test('rejects negative lateFeeCents', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: -1 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('lateFeeCents');
  });

  test('rejects non-integer lateFeeCents', () => {
    const { error } = updatePaymentSchema.validate({ lateFeeCents: 1.5 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('lateFeeCents');
  });

  test('rejects zero amount', () => {
    const { error } = updatePaymentSchema.validate({ amount: 0 });
    expect(error).toBeDefined();
  });

  test('rejects negative amount', () => {
    const { error } = updatePaymentSchema.validate({ amount: -500 });
    expect(error).toBeDefined();
  });

  test('rejects amount exceeding max', () => {
    const { error } = updatePaymentSchema.validate({ amount: 1000001 });
    expect(error).toBeDefined();
  });

  test('rejects invalid method', () => {
    const { error } = updatePaymentSchema.validate({ method: 'crypto' });
    expect(error).toBeDefined();
  });

  test('rejects reference exceeding 200 chars', () => {
    const { error } = updatePaymentSchema.validate({ reference: 'x'.repeat(201) });
    expect(error).toBeDefined();
  });

  test('rejects notes exceeding 1000 chars', () => {
    const { error } = updatePaymentSchema.validate({ notes: 'x'.repeat(1001) });
    expect(error).toBeDefined();
  });
});

// ── paymentStatusSchema ──
describe('paymentStatusSchema', () => {
  test('accepts each valid status', () => {
    VALID_PAYMENT_STATUSES.forEach((status) => {
      const { error } = paymentStatusSchema.validate({ status });
      expect(error).toBeUndefined();
    });
  });

  test('rejects missing status', () => {
    const { error } = paymentStatusSchema.validate({});
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  test('rejects invalid status', () => {
    const { error } = paymentStatusSchema.validate({ status: 'refunded' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  test('rejects empty string status', () => {
    const { error } = paymentStatusSchema.validate({ status: '' });
    expect(error).toBeDefined();
  });
});
