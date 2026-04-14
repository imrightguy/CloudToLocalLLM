/**
 * Lease Joi validation schema tests
 * Covers: leaseSchema, updateLeaseSchema, leaseStatusSchema, VALID_TRANSITIONS
 */
const {
  leaseSchema,
  updateLeaseSchema,
  leaseStatusSchema,
  VALID_LEASE_STATUSES,
  VALID_TRANSITIONS,
} = require('../src/models/lease');

// ── Helpers ──
const validLease = () => ({
  unitId: '550e8400-e29b-41d4-a716-446655440000',
  leadId: null,
  tenantFirstName: 'Jean',
  tenantLastName: 'Tremblay',
  tenantEmail: 'jean@example.com',
  tenantPhone: '+15145551234',
  rent: 1200,
  deposit: 1200,
  startDate: '2026-07-01',
  endDate: '2027-06-30',
  terms: { petsAllowed: false },
});

// ── leaseSchema ──
describe('leaseSchema', () => {
  test('accepts a valid lease', () => {
    const { error, value } = leaseSchema.validate(validLease());
    expect(error).toBeUndefined();
    expect(value.tenantFirstName).toBe('Jean');
    expect(value.terms).toEqual({ petsAllowed: false });
  });

  test('applies defaults for optional fields', () => {
    const minimal = {
      unitId: '550e8400-e29b-41d4-a716-446655440000',
      tenantFirstName: 'Marie',
      tenantLastName: 'Dupont',
      rent: 1000,
      startDate: '2026-07-01',
      endDate: '2027-06-30',
    };
    const { error, value } = leaseSchema.validate(minimal);
    expect(error).toBeUndefined();
    expect(value.deposit).toBe(0);
    expect(value.terms).toEqual({});
    expect(value.leadId).toBeUndefined();
  });

  test('rejects missing unitId', () => {
    const { error } = leaseSchema.validate({
      tenantFirstName: 'A', tenantLastName: 'B', rent: 1,
      startDate: '2026-07-01', endDate: '2027-06-30',
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('unitId');
  });

  test('rejects invalid unitId', () => {
    const { error } = leaseSchema.validate({ ...validLease(), unitId: 'not-uuid' });
    expect(error).toBeDefined();
  });

  test('accepts null leadId', () => {
    const { error } = leaseSchema.validate({ ...validLease(), leadId: null });
    expect(error).toBeUndefined();
  });

  test('accepts valid leadId', () => {
    const { error } = leaseSchema.validate({ ...validLease(), leadId: '660e8400-e29b-41d4-a716-446655440001' });
    expect(error).toBeUndefined();
  });

  test('rejects missing tenantFirstName', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantFirstName: undefined });
    expect(error).toBeDefined();
  });

  test('rejects empty tenantFirstName', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantFirstName: '' });
    expect(error).toBeDefined();
  });

  test('rejects tenantFirstName > 200 chars', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantFirstName: 'A'.repeat(201) });
    expect(error).toBeDefined();
  });

  test('rejects missing tenantLastName', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantLastName: undefined });
    expect(error).toBeDefined();
  });

  test('rejects tenantLastName > 200 chars', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantLastName: 'B'.repeat(201) });
    expect(error).toBeDefined();
  });

  test('rejects invalid tenantEmail', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantEmail: 'not-email' });
    expect(error).toBeDefined();
  });

  test('accepts null tenantEmail', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantEmail: null });
    expect(error).toBeUndefined();
  });

  test('accepts empty tenantEmail', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantEmail: '' });
    expect(error).toBeUndefined();
  });

  test('rejects invalid tenantPhone', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantPhone: 'abc' });
    expect(error).toBeDefined();
  });

  test('accepts null tenantPhone', () => {
    const { error } = leaseSchema.validate({ ...validLease(), tenantPhone: null });
    expect(error).toBeUndefined();
  });

  test('rejects rent = 0', () => {
    const { error } = leaseSchema.validate({ ...validLease(), rent: 0 });
    expect(error).toBeDefined();
  });

  test('rejects negative rent', () => {
    const { error } = leaseSchema.validate({ ...validLease(), rent: -100 });
    expect(error).toBeDefined();
  });

  test('rejects rent > 100000', () => {
    const { error } = leaseSchema.validate({ ...validLease(), rent: 100001 });
    expect(error).toBeDefined();
  });

  test('rejects non-integer rent', () => {
    const { error } = leaseSchema.validate({ ...validLease(), rent: 1200.50 });
    expect(error).toBeDefined();
  });

  test('rejects negative deposit', () => {
    const { error } = leaseSchema.validate({ ...validLease(), deposit: -1 });
    expect(error).toBeDefined();
  });

  test('rejects deposit > 200000', () => {
    const { error } = leaseSchema.validate({ ...validLease(), deposit: 200001 });
    expect(error).toBeDefined();
  });

  test('rejects missing startDate', () => {
    const { error } = leaseSchema.validate({ ...validLease(), startDate: undefined });
    expect(error).toBeDefined();
  });

  test('rejects missing endDate', () => {
    const { error } = leaseSchema.validate({ ...validLease(), endDate: undefined });
    expect(error).toBeDefined();
  });

  test('rejects endDate before startDate', () => {
    const { error } = leaseSchema.validate({
      ...validLease(),
      startDate: '2027-06-30',
      endDate: '2026-07-01',
    });
    expect(error).toBeDefined();
  });

  test('rejects non-object terms', () => {
    const { error } = leaseSchema.validate({ ...validLease(), terms: 'not-object' });
    expect(error).toBeDefined();
  });

  test('accepts empty terms object', () => {
    const { error } = leaseSchema.validate({ ...validLease(), terms: {} });
    expect(error).toBeUndefined();
  });
});

// ── updateLeaseSchema ──
describe('updateLeaseSchema', () => {
  test('accepts partial update with just rent', () => {
    const { error } = updateLeaseSchema.validate({ rent: 900 });
    expect(error).toBeUndefined();
  });

  test('accepts empty object', () => {
    const { error } = updateLeaseSchema.validate({});
    expect(error).toBeUndefined();
  });

  test('still validates field constraints', () => {
    const { error } = updateLeaseSchema.validate({ rent: -5 });
    expect(error).toBeDefined();
  });

  test('accepts partial date update', () => {
    const { error } = updateLeaseSchema.validate({ startDate: '2026-08-01' });
    expect(error).toBeUndefined();
  });

  test('accepts null tenantEmail', () => {
    const { error } = updateLeaseSchema.validate({ tenantEmail: null });
    expect(error).toBeUndefined();
  });

  test('rejects invalid tenantEmail', () => {
    const { error } = updateLeaseSchema.validate({ tenantEmail: 'bad' });
    expect(error).toBeDefined();
  });
});

// ── leaseStatusSchema ──
describe('leaseStatusSchema', () => {
  test('accepts all valid statuses', () => {
    for (const status of VALID_LEASE_STATUSES) {
      const { error } = leaseStatusSchema.validate({ status });
      expect(error).toBeUndefined();
    }
  });

  test('rejects invalid status', () => {
    const { error } = leaseStatusSchema.validate({ status: 'unknown' });
    expect(error).toBeDefined();
  });

  test('rejects missing status', () => {
    const { error } = leaseStatusSchema.validate({});
    expect(error).toBeDefined();
  });
});

// ── VALID_TRANSITIONS ──
describe('VALID_TRANSITIONS', () => {
  test('covers all statuses', () => {
    for (const status of VALID_LEASE_STATUSES) {
      expect(VALID_TRANSITIONS).toHaveProperty(status);
    }
  });

  test('terminated has no transitions', () => {
    expect(VALID_TRANSITIONS.terminated).toEqual([]);
  });

  test('renewed has no transitions', () => {
    expect(VALID_TRANSITIONS.renewed).toEqual([]);
  });

  test('draft can transition to active', () => {
    expect(VALID_TRANSITIONS.draft).toContain('active');
  });

  test('active can transition to expired', () => {
    expect(VALID_TRANSITIONS.active).toContain('expired');
  });

  test('active can transition to terminated', () => {
    expect(VALID_TRANSITIONS.active).toContain('terminated');
  });

  test('active can transition to renewed', () => {
    expect(VALID_TRANSITIONS.active).toContain('renewed');
  });

  test('expired can transition to renewed', () => {
    expect(VALID_TRANSITIONS.expired).toContain('renewed');
  });

  test('all target statuses are valid', () => {
    for (const [_from, targets] of Object.entries(VALID_TRANSITIONS)) {
      for (const to of targets) {
        expect(VALID_LEASE_STATUSES).toContain(to);
      }
    }
  });
});
