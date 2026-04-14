const {
  leaseSchema,
  updateLeaseSchema,
  leaseStatusSchema,
  VALID_LEASE_STATUSES,
  VALID_TRANSITIONS,
} = require('../src/models/lease');

const VALID_UUID = '550e8400-e29b-41d4-a716-446655440000';
const VALID_UUID_2 = '660e8400-e29b-41d4-a716-446655440001';

// ─── leaseSchema Validation ───

describe('leaseSchema', () => {
  const validLease = {
    unitId: VALID_UUID,
    tenantFirstName: 'Jean',
    tenantLastName: 'Tremblay',
    rent: 1200,
    startDate: '2026-07-01',
    endDate: '2027-06-30',
  };

  it('accepts a valid lease with required fields only', () => {
    const { error } = leaseSchema.validate(validLease);
    expect(error).toBeUndefined();
  });

  it('accepts a valid lease with all optional fields', () => {
    const { error, value } = leaseSchema.validate({
      ...validLease,
      leadId: VALID_UUID_2,
      tenantEmail: 'jean@example.com',
      tenantPhone: '+1 514-555-1234',
      deposit: 1200,
      terms: { pets: false, smoking: false },
    });
    expect(error).toBeUndefined();
    expect(value.deposit).toBe(1200);
  });

  it('defaults deposit to 0', () => {
    const { value } = leaseSchema.validate(validLease);
    expect(value.deposit).toBe(0);
  });

  it('defaults terms to empty object', () => {
    const { value } = leaseSchema.validate(validLease);
    expect(value.terms).toEqual({});
  });

  it('rejects missing unitId', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      unitId: undefined,
    });
    expect(error.details[0].message).toMatch(/unit/i);
  });

  it('rejects invalid unitId format', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      unitId: 'not-a-uuid',
    });
    expect(error.details[0].message).toMatch(/uuid/i);
  });

  it('accepts null leadId', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      leadId: null,
    });
    expect(error).toBeUndefined();
  });

  it('rejects invalid leadId format', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      leadId: 'bad-id',
    });
    expect(error.details[0].message).toMatch(/uuid/i);
  });

  it('rejects missing tenantFirstName', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      tenantFirstName: undefined,
    });
    expect(error.details[0].message).toMatch(/prénom/i);
  });

  it('rejects empty tenantFirstName', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      tenantFirstName: '',
    });
    expect(error).toBeDefined();
  });

  it('rejects tenantFirstName over 200 chars', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      tenantFirstName: 'X'.repeat(201),
    });
    expect(error.details[0].message).toMatch(/200/i);
  });

  it('rejects missing tenantLastName', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      tenantLastName: undefined,
    });
    expect(error.details[0].message).toMatch(/nom/i);
  });

  it('rejects invalid tenantEmail', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      tenantEmail: 'not-an-email',
    });
    expect(error.details[0].message).toMatch(/courriel/i);
  });

  it('accepts null tenantEmail', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      tenantEmail: null,
    });
    expect(error).toBeUndefined();
  });

  it('accepts valid tenantPhone formats', () => {
    const phones = ['+1 514-555-1234', '5145551234', '+33 1 23 45 67 89'];
    phones.forEach((phone) => {
      const { error } = leaseSchema.validate({
        ...validLease,
        tenantPhone: phone,
      });
      expect(error).toBeUndefined();
    });
  });

  it('rejects invalid tenantPhone', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      tenantPhone: 'abc',
    });
    expect(error.details[0].message).toMatch(/téléphone/i);
  });

  it('rejects missing rent', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      rent: undefined,
    });
    expect(error).toBeDefined();
  });

  it('rejects rent of 0', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      rent: 0,
    });
    expect(error.details[0].message).toMatch(/supérieur à 0/i);
  });

  it('rejects rent over 100000', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      rent: 100001,
    });
    expect(error.details[0].message).toMatch(/100 000/i);
  });

  it('rejects non-integer rent', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      rent: 1200.50,
    });
    expect(error.details[0].message).toMatch(/entier/i);
  });

  it('rejects negative deposit', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      deposit: -100,
    });
    expect(error.details[0].message).toMatch(/négatif/i);
  });

  it('rejects deposit over 200000', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      deposit: 200001,
    });
    expect(error).toBeDefined();
  });

  it('rejects missing startDate', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      startDate: undefined,
    });
    expect(error).toBeDefined();
  });

  it('rejects missing endDate', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      endDate: undefined,
    });
    expect(error).toBeDefined();
  });

  it('rejects endDate before startDate', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      startDate: '2027-06-30',
      endDate: '2026-07-01',
    });
    expect(error.details[0].message).toMatch(/après/i);
  });

  it('rejects non-object terms', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      terms: 'invalid',
    });
    expect(error.details[0].message).toMatch(/objet/i);
  });
});

// ─── updateLeaseSchema Validation ───

describe('updateLeaseSchema', () => {
  it('accepts empty update (all fields optional)', () => {
    const { error } = updateLeaseSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('accepts partial update with tenant names', () => {
    const { error } = updateLeaseSchema.validate({
      tenantFirstName: 'Marie',
      tenantLastName: 'Dubois',
    });
    expect(error).toBeUndefined();
  });

  it('accepts rent update', () => {
    const { error } = updateLeaseSchema.validate({
      rent: 1500,
    });
    expect(error).toBeUndefined();
  });

  it('accepts date updates', () => {
    const { error } = updateLeaseSchema.validate({
      startDate: '2026-08-01',
      endDate: '2027-07-31',
    });
    expect(error).toBeUndefined();
  });

  it('accepts terms update', () => {
    const { error } = updateLeaseSchema.validate({
      terms: { pets: true },
    });
    expect(error).toBeUndefined();
  });

  it('rejects empty tenantFirstName', () => {
    const { error } = updateLeaseSchema.validate({
      tenantFirstName: '',
    });
    expect(error).toBeDefined();
  });

  it('rejects negative rent', () => {
    const { error } = updateLeaseSchema.validate({
      rent: -100,
    });
    expect(error).toBeDefined();
  });

  it('rejects invalid email', () => {
    const { error } = updateLeaseSchema.validate({
      tenantEmail: 'bad',
    });
    expect(error).toBeDefined();
  });

  it('accepts null email', () => {
    const { error } = updateLeaseSchema.validate({
      tenantEmail: null,
    });
    expect(error).toBeUndefined();
  });

  it('accepts null phone', () => {
    const { error } = updateLeaseSchema.validate({
      tenantPhone: null,
    });
    expect(error).toBeUndefined();
  });
});

// ─── leaseStatusSchema Validation ───

describe('leaseStatusSchema', () => {
  it('accepts all valid statuses', () => {
    VALID_LEASE_STATUSES.forEach((status) => {
      const { error } = leaseStatusSchema.validate({ status });
      expect(error).toBeUndefined();
    });
  });

  it('rejects missing status', () => {
    const { error } = leaseStatusSchema.validate({});
    expect(error).toBeDefined();
  });

  it('rejects invalid status', () => {
    const { error } = leaseStatusSchema.validate({ status: 'pending' });
    expect(error).toBeDefined();
  });
});

// ─── VALID_TRANSITIONS ───

describe('VALID_TRANSITIONS', () => {
  it('allows draft → active', () => {
    expect(VALID_TRANSITIONS.draft).toContain('active');
  });

  it('allows draft → terminated', () => {
    expect(VALID_TRANSITIONS.draft).toContain('terminated');
  });

  it('allows active → expired', () => {
    expect(VALID_TRANSITIONS.active).toContain('expired');
  });

  it('allows active → terminated', () => {
    expect(VALID_TRANSITIONS.active).toContain('terminated');
  });

  it('allows active → renewed', () => {
    expect(VALID_TRANSITIONS.active).toContain('renewed');
  });

  it('allows expired → renewed', () => {
    expect(VALID_TRANSITIONS.expired).toContain('renewed');
  });

  it('does not allow terminated transitions', () => {
    expect(VALID_TRANSITIONS.terminated).toEqual([]);
  });

  it('does not allow renewed transitions', () => {
    expect(VALID_TRANSITIONS.renewed).toEqual([]);
  });

  it('does not allow draft → expired directly', () => {
    expect(VALID_TRANSITIONS.draft).not.toContain('expired');
  });

  it('does not allow draft → renewed directly', () => {
    expect(VALID_TRANSITIONS.draft).not.toContain('renewed');
  });
});

// ─── Controller logic tests (computeAutoStatus & toPublicLease) ───

describe('lease controller helpers', () => {
  // Re-implement computeAutoStatus from the controller for testing
  const computeAutoStatus = (startDate, endDate) => {
    const now = new Date();
    if (now < startDate) return 'draft';
    if (now > endDate) return 'expired';
    return 'active';
  };

  it('returns draft when start date is in the future', () => {
    const result = computeAutoStatus(
      new Date('2099-01-01'),
      new Date('2100-01-01'),
    );
    expect(result).toBe('draft');
  });

  it('returns expired when end date is in the past', () => {
    const result = computeAutoStatus(
      new Date('2000-01-01'),
      new Date('2001-01-01'),
    );
    expect(result).toBe('expired');
  });

  it('returns active when now is between start and end', () => {
    const result = computeAutoStatus(
      new Date('2020-01-01'),
      new Date('2099-01-01'),
    );
    expect(result).toBe('active');
  });

  // Re-implement toPublicLease from the controller for testing
  const toPublicLease = (lease) => ({
    ...lease,
    rent: lease.rentCents / 100,
    deposit: lease.depositCents / 100,
  });

  it('toPublicLease converts cents to dollars', () => {
    const result = toPublicLease({
      id: '1',
      rentCents: 120000,
      depositCents: 60000,
      status: 'draft',
    });
    expect(result.rent).toBe(1200);
    expect(result.deposit).toBe(600);
    expect(result.status).toBe('draft');
  });

  it('toPublicLease handles zero deposit', () => {
    const result = toPublicLease({
      rentCents: 95000,
      depositCents: 0,
    });
    expect(result.deposit).toBe(0);
  });
});
