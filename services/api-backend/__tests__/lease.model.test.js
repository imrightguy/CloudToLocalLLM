/**
 * Lease Joi validation schema tests
 * Covers: leaseSchema, updateLeaseSchema, leaseStatusSchema, VALID_LEASE_STATUSES, VALID_TRANSITIONS
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
  tenantFirstName: 'Jean',
  tenantLastName: 'Tremblay',
  tenantEmail: 'jean.tremblay@example.com',
  tenantPhone: '+1 514-555-1234',
  rent: 1200,
  deposit: 1200,
  startDate: '2025-07-01',
  endDate: '2026-06-30',
  terms: { petsAllowed: false },
});

// ══════════════════════════════════════════
// VALID_LEASE_STATUSES
// ══════════════════════════════════════════
describe('VALID_LEASE_STATUSES', () => {
  test('contains all expected statuses', () => {
    expect(VALID_LEASE_STATUSES).toEqual(
      expect.arrayContaining(['draft', 'active', 'expired', 'terminated', 'renewed'])
    );
  });

  test('has exactly 5 statuses', () => {
    expect(VALID_LEASE_STATUSES).toHaveLength(5);
  });
});

// ══════════════════════════════════════════
// VALID_TRANSITIONS
// ══════════════════════════════════════════
describe('VALID_TRANSITIONS', () => {
  test('draft can transition to active or terminated', () => {
    expect(VALID_TRANSITIONS.draft).toEqual(['active', 'terminated']);
  });

  test('active can transition to expired, terminated, or renewed', () => {
    expect(VALID_TRANSITIONS.active).toEqual(['expired', 'terminated', 'renewed']);
  });

  test('expired can only transition to renewed', () => {
    expect(VALID_TRANSITIONS.expired).toEqual(['renewed']);
  });

  test('terminated has no transitions', () => {
    expect(VALID_TRANSITIONS.terminated).toEqual([]);
  });

  test('renewed has no transitions', () => {
    expect(VALID_TRANSITIONS.renewed).toEqual([]);
  });

  test('every status key exists in VALID_LEASE_STATUSES', () => {
    Object.keys(VALID_TRANSITIONS).forEach((status) => {
      expect(VALID_LEASE_STATUSES).toContain(status);
    });
  });
});

// ══════════════════════════════════════════
// leaseSchema — valid cases
// ══════════════════════════════════════════
describe('leaseSchema — valid leases', () => {
  test('accepts a fully populated valid lease', () => {
    const { error, value } = leaseSchema.validate(validLease());
    expect(error).toBeUndefined();
    expect(value.unitId).toBe('550e8400-e29b-41d4-a716-446655440000');
    expect(value.rent).toBe(1200);
  });

  test('accepts lease with null leadId', () => {
    const lease = { ...validLease(), leadId: null };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('accepts lease with valid leadId UUID', () => {
    const lease = { ...validLease(), leadId: '660e8400-e29b-41d4-a716-446655440001' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('accepts null tenantEmail', () => {
    const lease = { ...validLease(), tenantEmail: null };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('accepts empty string tenantEmail', () => {
    const lease = { ...validLease(), tenantEmail: '' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('accepts null tenantPhone', () => {
    const lease = { ...validLease(), tenantPhone: null };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('accepts empty string tenantPhone', () => {
    const lease = { ...validLease(), tenantPhone: '' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('defaults deposit to 0 when omitted', () => {
    const { deposit, ...lease } = validLease();
    const { error, value } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
    expect(value.deposit).toBe(0);
  });

  test('defaults terms to {} when omitted', () => {
    const { terms, ...lease } = validLease();
    const { error, value } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
    expect(value.terms).toEqual({});
  });

  test('accepts phone with plus prefix', () => {
    const lease = { ...validLease(), tenantPhone: '+15145551234' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('accepts phone with dashes and parentheses', () => {
    const lease = { ...validLease(), tenantPhone: '(514) 555-1234' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });
});

// ══════════════════════════════════════════
// leaseSchema — required fields
// ══════════════════════════════════════════
describe('leaseSchema — required fields', () => {
  test('rejects missing unitId', () => {
    const { unitId, ...lease } = validLease();
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects missing tenantFirstName', () => {
    const { tenantFirstName, ...lease } = validLease();
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects missing tenantLastName', () => {
    const { tenantLastName, ...lease } = validLease();
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects missing rent', () => {
    const { rent, ...lease } = validLease();
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects missing startDate', () => {
    const { startDate, ...lease } = validLease();
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects missing endDate', () => {
    const { endDate, ...lease } = validLease();
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });
});

// ══════════════════════════════════════════
// leaseSchema — field validations
// ══════════════════════════════════════════
describe('leaseSchema — field validations', () => {
  test('rejects invalid unitId (not a UUID)', () => {
    const lease = { ...validLease(), unitId: 'not-a-uuid' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects invalid leadId (not a UUID)', () => {
    const lease = { ...validLease(), leadId: 'bad-lead-id' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects empty tenantFirstName', () => {
    const lease = { ...validLease(), tenantFirstName: '' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects tenantFirstName over 200 chars', () => {
    const lease = { ...validLease(), tenantFirstName: 'a'.repeat(201) };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('accepts tenantFirstName at exactly 200 chars', () => {
    const lease = { ...validLease(), tenantFirstName: 'a'.repeat(200) };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('rejects empty tenantLastName', () => {
    const lease = { ...validLease(), tenantLastName: '' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects tenantLastName over 200 chars', () => {
    const lease = { ...validLease(), tenantLastName: 'a'.repeat(201) };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects invalid tenantEmail format', () => {
    const lease = { ...validLease(), tenantEmail: 'not-an-email' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects invalid tenantPhone format', () => {
    const lease = { ...validLease(), tenantPhone: 'abc' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects non-integer rent', () => {
    const lease = { ...validLease(), rent: 1200.50 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects rent of 0', () => {
    const lease = { ...validLease(), rent: 0 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects negative rent', () => {
    const lease = { ...validLease(), rent: -100 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects rent over 100000', () => {
    const lease = { ...validLease(), rent: 100001 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('accepts rent at max (100000)', () => {
    const lease = { ...validLease(), rent: 100000 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('rejects non-integer deposit', () => {
    const lease = { ...validLease(), deposit: 500.99 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects negative deposit', () => {
    const lease = { ...validLease(), deposit: -1 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('accepts deposit of 0', () => {
    const lease = { ...validLease(), deposit: 0 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeUndefined();
  });

  test('rejects deposit over 200000', () => {
    const lease = { ...validLease(), deposit: 200001 };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects endDate before startDate', () => {
    const lease = { ...validLease(), startDate: '2026-06-30', endDate: '2025-07-01' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });

  test('rejects non-object terms', () => {
    const lease = { ...validLease(), terms: 'not an object' };
    const { error } = leaseSchema.validate(lease);
    expect(error).toBeDefined();
  });
});

// ══════════════════════════════════════════
// updateLeaseSchema
// ══════════════════════════════════════════
describe('updateLeaseSchema', () => {
  test('accepts partial update with just rent', () => {
    const { error, value } = updateLeaseSchema.validate({ rent: 1500 });
    expect(error).toBeUndefined();
    expect(value.rent).toBe(1500);
  });

  test('accepts partial update with just tenantFirstName', () => {
    const { error } = updateLeaseSchema.validate({ tenantFirstName: 'Marie' });
    expect(error).toBeUndefined();
  });

  test('accepts partial update with just tenantEmail', () => {
    const { error } = updateLeaseSchema.validate({ tenantEmail: 'marie@example.com' });
    expect(error).toBeUndefined();
  });

  test('accepts empty object (no-op update)', () => {
    const { error } = updateLeaseSchema.validate({});
    expect(error).toBeUndefined();
  });

  test('rejects invalid rent in update', () => {
    const { error } = updateLeaseSchema.validate({ rent: -50 });
    expect(error).toBeDefined();
  });

  test('rejects invalid email in update', () => {
    const { error } = updateLeaseSchema.validate({ tenantEmail: 'bad' });
    expect(error).toBeDefined();
  });

  test('rejects empty tenantFirstName in update', () => {
    const { error } = updateLeaseSchema.validate({ tenantFirstName: '' });
    expect(error).toBeDefined();
  });

  test('rejects non-integer rent in update', () => {
    const { error } = updateLeaseSchema.validate({ rent: 1000.5 });
    expect(error).toBeDefined();
  });

  test('accepts null tenantEmail in update', () => {
    const { error } = updateLeaseSchema.validate({ tenantEmail: null });
    expect(error).toBeUndefined();
  });

  test('accepts null tenantPhone in update', () => {
    const { error } = updateLeaseSchema.validate({ tenantPhone: null });
    expect(error).toBeUndefined();
  });

  test('accepts valid startDate update', () => {
    const { error } = updateLeaseSchema.validate({ startDate: '2025-08-01' });
    expect(error).toBeUndefined();
  });

  test('accepts valid terms object in update', () => {
    const { error } = updateLeaseSchema.validate({ terms: { petsAllowed: true } });
    expect(error).toBeUndefined();
  });
});

// ══════════════════════════════════════════
// leaseStatusSchema
// ══════════════════════════════════════════
describe('leaseStatusSchema', () => {
  VALID_LEASE_STATUSES.forEach((status) => {
    test(`accepts status "${status}"`, () => {
      const { error, value } = leaseStatusSchema.validate({ status });
      expect(error).toBeUndefined();
      expect(value.status).toBe(status);
    });
  });

  test('rejects missing status', () => {
    const { error } = leaseStatusSchema.validate({});
    expect(error).toBeDefined();
  });

  test('rejects invalid status', () => {
    const { error } = leaseStatusSchema.validate({ status: 'invalid_status' });
    expect(error).toBeDefined();
  });

  test('rejects empty string status', () => {
    const { error } = leaseStatusSchema.validate({ status: '' });
    expect(error).toBeDefined();
  });

  test('rejects numeric status', () => {
    const { error } = leaseStatusSchema.validate({ status: 123 });
    expect(error).toBeDefined();
  });
});
