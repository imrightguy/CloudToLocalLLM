const {
  buildingSchema, unitSchema, updateBuildingSchema, updateUnitSchema,
} = require('../src/models/building');

// ─── Building Schema Validation ───

describe('buildingSchema', () => {
  const validBuilding = {
    name: 'Édifice Mont-Royal',
    address: '1234 Rue Saint-Denis',
    totalUnits: 12,
  };

  it('accepts a valid building with required fields only', () => {
    const { error } = buildingSchema.validate(validBuilding);
    expect(error).toBeUndefined();
  });

  it('accepts a valid building with all optional fields', () => {
    const { error } = buildingSchema.validate({
      ...validBuilding,
      occupiedUnits: 8,
      monthlyRevenue: 9600,
      managerId: '550e8400-e29b-41d4-a716-446655440000',
      properties: {
        yearBuilt: 1985,
        elevator: true,
        gym: false,
        pool: false,
        parking: true,
        laundry: true,
        petFriendly: true,
        security: true,
        description: 'Nice building near metro',
        images: ['https://example.com/photo.jpg'],
        amenities: ['gym', 'parking'],
      },
    });
    expect(error).toBeUndefined();
  });

  it('rejects missing name', () => {
    const { error } = buildingSchema.validate({ address: '1234 Rue', totalUnits: 5 });
    expect(error.details[0].message).toMatch(/name/i);
  });

  it('rejects name shorter than 2 characters', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, name: 'A' });
    expect(error.details[0].message).toMatch(/at least 2/i);
  });

  it('rejects name longer than 100 characters', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, name: 'X'.repeat(101) });
    expect(error.details[0].message).toMatch(/100/i);
  });

  it('rejects missing address', () => {
    const { error } = buildingSchema.validate({ name: 'Test', totalUnits: 5 });
    expect(error.details[0].message).toMatch(/address/i);
  });

  it('rejects address shorter than 5 characters', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, address: '123' });
    expect(error.details[0].message).toMatch(/at least 5/i);
  });

  it('rejects totalUnits as a string', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, totalUnits: 'five' });
    expect(error.details[0].message).toMatch(/number/i);
  });

  it('rejects totalUnits of 0', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, totalUnits: 0 });
    expect(error.details[0].message).toMatch(/at least 1/i);
  });

  it('rejects occupiedUnits exceeding totalUnits', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, totalUnits: 5, occupiedUnits: 10 });
    expect(error.details[0].message).toMatch(/cannot exceed/i);
  });

  it('rejects invalid managerId (not a UUID)', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, managerId: 'not-a-uuid' });
    expect(error.details[0].message).toMatch(/uuid/i);
  });

  it('allows null managerId', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, managerId: null });
    expect(error).toBeUndefined();
  });

  it('rejects yearBuilt in the future', () => {
    const futureYear = new Date().getFullYear() + 1;
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { yearBuilt: futureYear },
    });
    expect(error.details[0].message).toMatch(/future/i);
  });

  it('rejects more than 20 images', () => {
    const images = Array.from({ length: 21 }, (_, i) => `https://example.com/${i}.jpg`);
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { images },
    });
    expect(error.details[0].message).toMatch(/20/i);
  });

  it('rejects invalid image URL', () => {
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { images: ['not-a-url'] },
    });
    expect(error.details[0].message).toMatch(/valid url/i);
  });

  it('defaults occupiedUnits to 0', () => {
    const { value } = buildingSchema.validate(validBuilding);
    expect(value.occupiedUnits).toBe(0);
  });

  it('defaults properties to empty object', () => {
    const { value } = buildingSchema.validate(validBuilding);
    expect(value.properties).toEqual({});
  });
});

// ─── Unit Schema Validation ───

describe('unitSchema', () => {
  const validUnit = {
    buildingId: '550e8400-e29b-41d4-a716-446655440000',
    label: '4A',
    rent: 1200,
    status: 'vacant',
  };

  it('accepts a valid unit with required fields', () => {
    const { error } = unitSchema.validate(validUnit);
    expect(error).toBeUndefined();
  });

  it('accepts a valid unit with all optional fields', () => {
    const { error } = unitSchema.validate({
      ...validUnit,
      bedrooms: 2,
      bathrooms: 1,
      squareFeet: 800,
      description: 'Sunny 4½',
      amenities: ['fridge', 'stove'],
      tenantName: 'Jean Dupont',
      tenantPhone: '+1 514-555-0123',
      tenantLeaseEnd: '2026-12-31',
      features: {
        furnished: true,
        parkingIncluded: false,
        airConditioning: true,
        balcony: true,
      },
    });
    expect(error).toBeUndefined();
  });

  it('rejects missing buildingId', () => {
    const { error } = unitSchema.validate({ label: '4A', rent: 1200, status: 'vacant' });
    expect(error.details[0].message).toMatch(/required/i);
  });

  it('rejects invalid buildingId (not UUID)', () => {
    const { error } = unitSchema.validate({ ...validUnit, buildingId: 'abc' });
    expect(error.details[0].message).toMatch(/UUID/i);
  });

  it('rejects label shorter than 2 characters', () => {
    const { error } = unitSchema.validate({ ...validUnit, label: 'A' });
    expect(error.details[0].message).toMatch(/at least 2/i);
  });

  it('rejects label with special characters', () => {
    const { error } = unitSchema.validate({ ...validUnit, label: '4@#$' });
    expect(error.details[0].message).toMatch(/letters.*numbers/i);
  });

  it('rejects negative rent', () => {
    const { error } = unitSchema.validate({ ...validUnit, rent: -100 });
    expect(error.details[0].message).toMatch(/negative/i);
  });

  it('rejects rent exceeding $100,000', () => {
    const { error } = unitSchema.validate({ ...validUnit, rent: 100001 });
    expect(error.details[0].message).toMatch(/100.*000/i);
  });

  it('rejects invalid status', () => {
    const { error } = unitSchema.validate({ ...validUnit, status: 'unknown' });
    expect(error.details[0].message).toMatch(/vacant.*occupied.*maintenance/i);
  });

  it('rejects squareFeet less than 100', () => {
    const { error } = unitSchema.validate({ ...validUnit, squareFeet: 50 });
    expect(error.details[0].message).toMatch(/at least 100/i);
  });

  it('rejects bedrooms exceeding 10', () => {
    const { error } = unitSchema.validate({ ...validUnit, bedrooms: 11 });
    expect(error.details[0].message).toMatch(/10/i);
  });

  it('rejects invalid phone number', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantPhone: '123' });
    expect(error.details[0].message).toMatch(/phone number format/i);
  });

  it('rejects invalid tenantLeaseEnd format', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantLeaseEnd: 'not-a-date' });
    expect(error).toBeDefined();
  });

  it('allows null tenantLeaseEnd', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantLeaseEnd: null });
    expect(error).toBeUndefined();
  });

  it('allows empty string tenantName', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantName: '' });
    expect(error).toBeUndefined();
  });

  it('requires status (default does not apply when key is missing)', () => {
    const { error } = unitSchema.validate({
      buildingId: validUnit.buildingId,
      label: '4B',
      rent: 1000,
    });
    expect(error).toBeDefined();
    expect(error.details[0].message).toMatch(/required/i);
  });

  it('defaults amenities to empty array', () => {
    const { value } = unitSchema.validate(validUnit);
    expect(value.amenities).toEqual([]);
  });

  it('defaults features to empty object', () => {
    const { value } = unitSchema.validate(validUnit);
    expect(value.features).toEqual({});
  });
});

// ─── Update Building Schema ───

describe('updateBuildingSchema', () => {
  it('accepts partial update with name only', () => {
    const { error } = updateBuildingSchema.validate({ name: 'New Name' });
    expect(error).toBeUndefined();
  });

  it('accepts empty object (no-op update)', () => {
    const { error } = updateBuildingSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('rejects invalid name length on update', () => {
    const { error } = updateBuildingSchema.validate({ name: 'A' });
    expect(error.details[0].message).toMatch(/at least 2/i);
  });

  it('rejects invalid totalUnits on update', () => {
    const { error } = updateBuildingSchema.validate({ totalUnits: 0 });
    expect(error.details[0].message).toMatch(/at least 1/i);
  });
});

// ─── Update Unit Schema ───

describe('updateUnitSchema', () => {
  it('accepts partial update with rent only', () => {
    const { error } = updateUnitSchema.validate({ rent: 1500 });
    expect(error).toBeUndefined();
  });

  it('accepts empty object (no-op update)', () => {
    const { error } = updateUnitSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('rejects invalid status on update', () => {
    const { error } = updateUnitSchema.validate({ status: 'deleted' });
    expect(error.details[0].message).toMatch(/vacant.*occupied.*maintenance/i);
  });

  it('rejects invalid label pattern on update', () => {
    const { error } = updateUnitSchema.validate({ label: 'Unit@#$' });
    expect(error.details[0].message).toMatch(/letters.*numbers/i);
  });
});
