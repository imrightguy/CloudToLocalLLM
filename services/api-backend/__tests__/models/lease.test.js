const {
  leaseSchema,
  updateLeaseSchema,
  leaseStatusSchema,
  VALID_LEASE_STATUSES,
  VALID_TRANSITIONS,
} = require('../../src/models/lease');

describe('leaseSchema', () => {
  const validLease = {
    unitId: '550e8400-e29b-41d4-a716-446655440000',
    tenantFirstName: 'Jean',
    tenantLastName: 'Tremblay',
    rent: 85000,
    startDate: '2026-07-01',
    endDate: '2027-06-30',
  };

  it('validates a minimal valid lease', () => {
    const { error, value } = leaseSchema.validate(validLease);
    expect(error).toBeUndefined();
    expect(value.unitId).toBe(validLease.unitId);
    expect(value.tenantFirstName).toBe('Jean');
    expect(value.tenantLastName).toBe('Tremblay');
    expect(value.rent).toBe(85000);
    expect(value.deposit).toBe(0);
    expect(value.terms).toEqual({});
  });

  it('validates a full lease with all optional fields', () => {
    const full = {
      ...validLease,
      leadId: '550e8400-e29b-41d4-a716-446655440001',
      tenantEmail: 'jean.tremblay@example.com',
      tenantPhone: '+1 514-555-1234',
      deposit: 85000,
      terms: { petsAllowed: false, parkingIncluded: true },
    };
    const { error, value } = leaseSchema.validate(full);
    expect(error).toBeUndefined();
    expect(value.leadId).toBe('550e8400-e29b-41d4-a716-446655440001');
    expect(value.tenantEmail).toBe('jean.tremblay@example.com');
    expect(value.deposit).toBe(85000);
    expect(value.terms.petsAllowed).toBe(false);
  });

  it('rejects missing unitId', () => {
    const { error } = leaseSchema.validate({ ...validLease, unitId: undefined });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('unitId');
  });

  it('rejects invalid unitId', () => {
    const { error } = leaseSchema.validate({ ...validLease, unitId: 'not-a-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('unitId');
  });

  it('allows null leadId', () => {
    const { error } = leaseSchema.validate({ ...validLease, leadId: null });
    expect(error).toBeUndefined();
  });

  it('rejects invalid leadId', () => {
    const { error } = leaseSchema.validate({ ...validLease, leadId: 'bad-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('leadId');
  });

  it('rejects missing tenantFirstName', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantFirstName: undefined });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantFirstName');
  });

  it('rejects empty tenantFirstName', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantFirstName: '' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantFirstName');
  });

  it('rejects tenantFirstName over 200 characters', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantFirstName: 'A'.repeat(201) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantFirstName');
  });

  it('rejects missing tenantLastName', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantLastName: undefined });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantLastName');
  });

  it('rejects empty tenantLastName', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantLastName: '' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantLastName');
  });

  it('rejects tenantLastName over 200 characters', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantLastName: 'B'.repeat(201) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantLastName');
  });

  it('allows null tenantEmail', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantEmail: null });
    expect(error).toBeUndefined();
  });

  it('allows empty string tenantEmail', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantEmail: '' });
    expect(error).toBeUndefined();
  });

  it('rejects invalid tenantEmail', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantEmail: 'not-an-email' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantEmail');
  });

  it('allows null tenantPhone', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantPhone: null });
    expect(error).toBeUndefined();
  });

  it('allows empty string tenantPhone', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantPhone: '' });
    expect(error).toBeUndefined();
  });

  it('accepts valid phone formats', () => {
    const phones = ['+1 514-555-1234', '5145551234', '+1 (514) 555-1234', '514 555 1234'];
    for (const phone of phones) {
      const { error } = leaseSchema.validate({ ...validLease, tenantPhone: phone });
      expect(error).toBeUndefined();
    }
  });

  it('rejects invalid tenantPhone', () => {
    const { error } = leaseSchema.validate({ ...validLease, tenantPhone: 'abc' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('tenantPhone');
  });

  it('rejects missing rent', () => {
    const { error } = leaseSchema.validate({ ...validLease, rent: undefined });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('rent');
  });

  it('rejects non-integer rent', () => {
    const { error } = leaseSchema.validate({ ...validLease, rent: 850.50 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('rent');
  });

  it('rejects rent of 0', () => {
    const { error } = leaseSchema.validate({ ...validLease, rent: 0 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('rent');
  });

  it('rejects negative rent', () => {
    const { error } = leaseSchema.validate({ ...validLease, rent: -100 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('rent');
  });

  it('rejects rent over 100000', () => {
    const { error } = leaseSchema.validate({ ...validLease, rent: 100001 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('rent');
  });

  it('defaults deposit to 0', () => {
    const { value } = leaseSchema.validate(validLease);
    expect(value.deposit).toBe(0);
  });

  it('accepts valid deposit', () => {
    const { error } = leaseSchema.validate({ ...validLease, deposit: 85000 });
    expect(error).toBeUndefined();
  });

  it('rejects negative deposit', () => {
    const { error } = leaseSchema.validate({ ...validLease, deposit: -1 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('deposit');
  });

  it('rejects deposit over 200000', () => {
    const { error } = leaseSchema.validate({ ...validLease, deposit: 200001 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('deposit');
  });

  it('rejects non-integer deposit', () => {
    const { error } = leaseSchema.validate({ ...validLease, deposit: 100.50 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('deposit');
  });

  it('rejects missing startDate', () => {
    const { error } = leaseSchema.validate({ ...validLease, startDate: undefined });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('startDate');
  });

  it('rejects invalid startDate', () => {
    const { error } = leaseSchema.validate({ ...validLease, startDate: 'not-a-date' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('startDate');
  });

  it('rejects missing endDate', () => {
    const { error } = leaseSchema.validate({ ...validLease, endDate: undefined });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('endDate');
  });

  it('rejects invalid endDate', () => {
    const { error } = leaseSchema.validate({ ...validLease, endDate: 'not-a-date' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('endDate');
  });

  it('rejects endDate before startDate', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      startDate: '2027-01-01',
      endDate: '2026-12-31',
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('endDate');
  });

  it('rejects endDate equal to startDate', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      startDate: '2026-07-01',
      endDate: '2026-07-01',
    });
    expect(error).toBeDefined();
  });

  it('defaults terms to empty object', () => {
    const { value } = leaseSchema.validate(validLease);
    expect(value.terms).toEqual({});
  });

  it('accepts terms as object', () => {
    const { error } = leaseSchema.validate({
      ...validLease,
      terms: { parkingIncluded: true },
    });
    expect(error).toBeUndefined();
  });

  it('rejects terms as non-object', () => {
    const { error } = leaseSchema.validate({ ...validLease, terms: 'not-an-object' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('terms');
  });
});

describe('updateLeaseSchema', () => {
  it('validates empty object', () => {
    const { error } = updateLeaseSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('validates partial update with just rent', () => {
    const { error, value } = updateLeaseSchema.validate({ rent: 90000 });
    expect(error).toBeUndefined();
    expect(value.rent).toBe(90000);
  });

  it('validates partial update with tenant info', () => {
    const { error } = updateLeaseSchema.validate({
      tenantFirstName: 'Marie',
      tenantLastName: 'Gagnon',
      tenantEmail: 'marie@example.com',
      tenantPhone: '+1 514-555-9999',
    });
    expect(error).toBeUndefined();
  });

  it('still validates tenantFirstName min length', () => {
    const { error } = updateLeaseSchema.validate({ tenantFirstName: '' });
    expect(error).toBeDefined();
  });

  it('still validates tenantLastName min length', () => {
    const { error } = updateLeaseSchema.validate({ tenantLastName: '' });
    expect(error).toBeDefined();
  });

  it('still validates rent is integer', () => {
    const { error } = updateLeaseSchema.validate({ rent: 850.50 });
    expect(error).toBeDefined();
  });

  it('still validates rent min', () => {
    const { error } = updateLeaseSchema.validate({ rent: 0 });
    expect(error).toBeDefined();
  });

  it('still validates email format', () => {
    const { error } = updateLeaseSchema.validate({ tenantEmail: 'bad-email' });
    expect(error).toBeDefined();
  });

  it('still validates phone pattern', () => {
    const { error } = updateLeaseSchema.validate({ tenantPhone: 'xyz' });
    expect(error).toBeDefined();
  });

  it('still validates deposit range', () => {
    const { error } = updateLeaseSchema.validate({ deposit: -1 });
    expect(error).toBeDefined();
  });

  it('rejects null deposit on update', () => {
    const { error } = updateLeaseSchema.validate({ deposit: null });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('deposit');
  });

  it('validates date formats on update', () => {
    const { error } = updateLeaseSchema.validate({ startDate: 'not-a-date' });
    expect(error).toBeDefined();
  });

  it('allows updating terms', () => {
    const { error } = updateLeaseSchema.validate({ terms: { petsAllowed: true } });
    expect(error).toBeUndefined();
  });
});

describe('leaseStatusSchema', () => {
  it('validates all valid statuses', () => {
    for (const status of VALID_LEASE_STATUSES) {
      const { error } = leaseStatusSchema.validate({ status });
      expect(error).toBeUndefined();
    }
  });

  it('rejects invalid status', () => {
    const { error } = leaseStatusSchema.validate({ status: 'unknown' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  it('rejects missing status', () => {
    const { error } = leaseStatusSchema.validate({});
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  it('rejects empty status', () => {
    const { error } = leaseStatusSchema.validate({ status: '' });
    expect(error).toBeDefined();
  });
});

describe('VALID_TRANSITIONS', () => {
  it('contains all valid statuses as keys', () => {
    for (const status of VALID_LEASE_STATUSES) {
      expect(VALID_TRANSITIONS).toHaveProperty(status);
    }
  });

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

  it('terminated has no valid transitions', () => {
    expect(VALID_TRANSITIONS.terminated).toEqual([]);
  });

  it('renewed has no valid transitions', () => {
    expect(VALID_TRANSITIONS.renewed).toEqual([]);
  });
});
