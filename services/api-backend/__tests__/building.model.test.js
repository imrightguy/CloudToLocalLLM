/**
 * Building & Unit Joi validation schema tests
 * Covers: buildingSchema, unitSchema, updateBuildingSchema, updateUnitSchema
 */
const {
  buildingSchema,
  unitSchema,
  updateBuildingSchema,
  updateUnitSchema,
} = require('../src/models/building');

// ── Helpers ──
const validBuilding = () => ({
  name: 'Tour A',
  address: '123 Rue Principale, Montréal',
  city: 'Montreal',
  totalUnits: 50,
  occupiedUnits: 30,
  monthlyRevenue: 75000,
  managerId: '550e8400-e29b-41d4-a716-446655440000',
  properties: {
    yearBuilt: 1995,
    elevator: true,
    gym: false,
    pool: true,
    parking: true,
    laundry: false,
    petFriendly: false,
    security: true,
    description: 'Nice building downtown',
    images: ['https://example.com/img1.jpg'],
    amenities: ['spa', 'rooftop'],
  },
});

const validUnit = () => ({
  buildingId: '550e8400-e29b-41d4-a716-446655440000',
  label: 'Apt 101',
  rent: 1200,
  status: 'vacant',
  amenities: ['balcony'],
  squareFeet: 800,
  bedrooms: 2,
  bathrooms: 1,
  description: 'Bright apartment',
  features: { furnished: true, parkingIncluded: false },
  tenantName: null,
  tenantPhone: null,
  tenantLeaseEnd: null,
});

// ── buildingSchema ──
describe('buildingSchema', () => {
  test('accepts a valid building', () => {
    const { error, value } = buildingSchema.validate(validBuilding());
    expect(error).toBeUndefined();
    expect(value.name).toBe('Tour A');
    expect(value.occupiedUnits).toBe(30);
    expect(value.properties).toBeDefined();
  });

  test('applies defaults for optional fields', () => {
    const minimal = { name: 'AB', address: '12345', city: 'Montreal', totalUnits: 1 };
    const { error, value } = buildingSchema.validate(minimal);
    expect(error).toBeUndefined();
    expect(value.occupiedUnits).toBe(0);
    expect(value.monthlyRevenue).toBe(0);
    expect(value.properties).toEqual({});
  });

  test('rejects missing required name', () => {
    const { error } = buildingSchema.validate({ city: 'Montreal', address: '12345', totalUnits: 1 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  test('rejects name too short (<2 chars)', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), name: 'A' });
    expect(error).toBeDefined();
  });

  test('rejects name too long (>100 chars)', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), name: 'A'.repeat(101) });
    expect(error).toBeDefined();
  });

  test('rejects address too short (<5 chars)', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), address: '1234' });
    expect(error).toBeDefined();
  });

  test('rejects totalUnits < 1', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), totalUnits: 0 });
    expect(error).toBeDefined();
  });

  test('rejects totalUnits > 1000', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), totalUnits: 1001 });
    expect(error).toBeDefined();
  });

  test('rejects occupiedUnits > totalUnits', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), totalUnits: 5, occupiedUnits: 6 });
    expect(error).toBeDefined();
  });

  test('rejects negative monthlyRevenue', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), monthlyRevenue: -1 });
    expect(error).toBeDefined();
  });

  test('rejects invalid managerId', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), managerId: 'not-a-uuid' });
    expect(error).toBeDefined();
  });

  test('accepts null managerId', () => {
    const { error } = buildingSchema.validate({ ...validBuilding(), managerId: null });
    expect(error).toBeUndefined();
  });

  test('rejects yearBuilt before 1800', () => {
    const b = validBuilding();
    b.properties.yearBuilt = 1799;
    const { error } = buildingSchema.validate(b);
    expect(error).toBeDefined();
  });

  test('rejects yearBuilt in the future', () => {
    const b = validBuilding();
    b.properties.yearBuilt = new Date().getFullYear() + 1;
    const { error } = buildingSchema.validate(b);
    expect(error).toBeDefined();
  });

  test('rejects >20 images', () => {
    const b = validBuilding();
    b.properties.images = Array(21).fill('https://example.com/img.jpg');
    const { error } = buildingSchema.validate(b);
    expect(error).toBeDefined();
  });

  test('rejects non-URI images', () => {
    const b = validBuilding();
    b.properties.images = ['not-a-url'];
    const { error } = buildingSchema.validate(b);
    expect(error).toBeDefined();
  });

  test('rejects >50 amenities', () => {
    const b = validBuilding();
    b.properties.amenities = Array(51).fill('amenity');
    const { error } = buildingSchema.validate(b);
    expect(error).toBeDefined();
  });

  test('rejects description >2000 chars', () => {
    const b = validBuilding();
    b.properties.description = 'x'.repeat(2001);
    const { error } = buildingSchema.validate(b);
    expect(error).toBeDefined();
  });
});

// ── unitSchema ──
describe('unitSchema', () => {
  test('accepts a valid unit', () => {
    const { error, value } = unitSchema.validate(validUnit());
    expect(error).toBeUndefined();
    expect(value.buildingId).toBe('550e8400-e29b-41d4-a716-446655440000');
  });

  test('applies defaults for optional fields', () => {
    const minimal = {
      buildingId: '550e8400-e29b-41d4-a716-446655440000',
      label: 'A1',
      rent: 800,
      status: 'vacant',
    };
    const { error, value } = unitSchema.validate(minimal);
    expect(error).toBeUndefined();
    expect(value.amenities).toEqual([]);
    expect(value.features).toEqual({});
  });

  test('rejects missing buildingId', () => {
    const { error } = unitSchema.validate({ label: 'A1', rent: 800, status: 'vacant' });
    expect(error).toBeDefined();
  });

  test('rejects invalid buildingId', () => {
    const { error } = unitSchema.validate({ ...validUnit(), buildingId: 'bad-id' });
    expect(error).toBeDefined();
  });

  test('rejects label too short', () => {
    const { error } = unitSchema.validate({ ...validUnit(), label: 'A' });
    expect(error).toBeDefined();
  });

  test('rejects label with special characters', () => {
    const { error } = unitSchema.validate({ ...validUnit(), label: 'Apt@101' });
    expect(error).toBeDefined();
  });

  test('accepts label with hyphens and spaces', () => {
    const { error } = unitSchema.validate({ ...validUnit(), label: 'Apt 1-B' });
    expect(error).toBeUndefined();
  });

  test('rejects negative rent', () => {
    const { error } = unitSchema.validate({ ...validUnit(), rent: -1 });
    expect(error).toBeDefined();
  });

  test('rejects rent > 100000', () => {
    const { error } = unitSchema.validate({ ...validUnit(), rent: 100001 });
    expect(error).toBeDefined();
  });

  test('rejects invalid status', () => {
    const { error } = unitSchema.validate({ ...validUnit(), status: 'destroyed' });
    expect(error).toBeDefined();
  });

  test('accepts all valid statuses', () => {
    for (const s of ['vacant', 'occupied', 'maintenance']) {
      const { error } = unitSchema.validate({ ...validUnit(), status: s });
      expect(error).toBeUndefined();
    }
  });

  test('rejects squareFeet < 100', () => {
    const { error } = unitSchema.validate({ ...validUnit(), squareFeet: 50 });
    expect(error).toBeDefined();
  });

  test('rejects squareFeet > 10000', () => {
    const { error } = unitSchema.validate({ ...validUnit(), squareFeet: 10001 });
    expect(error).toBeDefined();
  });

  test('rejects bedrooms > 10', () => {
    const { error } = unitSchema.validate({ ...validUnit(), bedrooms: 11 });
    expect(error).toBeDefined();
  });

  test('rejects bathrooms > 10', () => {
    const { error } = unitSchema.validate({ ...validUnit(), bathrooms: 11 });
    expect(error).toBeDefined();
  });

  test('rejects invalid tenantPhone', () => {
    const { error } = unitSchema.validate({ ...validUnit(), tenantPhone: 'abc' });
    expect(error).toBeDefined();
  });

  test('accepts valid tenantPhone formats', () => {
    for (const phone of ['+15145551234', '514 555 1234', '(514) 555-1234']) {
      const { error } = unitSchema.validate({ ...validUnit(), tenantPhone: phone });
      expect(error).toBeUndefined();
    }
  });

  test('accepts null tenant fields', () => {
    const u = { ...validUnit(), tenantName: null, tenantPhone: null, tenantLeaseEnd: null };
    const { error } = unitSchema.validate(u);
    expect(error).toBeUndefined();
  });

  test('accepts valid tenantLeaseEnd', () => {
    const { error } = unitSchema.validate({ ...validUnit(), tenantLeaseEnd: '2026-12-31' });
    expect(error).toBeUndefined();
  });

  test('rejects >50 amenities', () => {
    const u = { ...validUnit(), amenities: Array(51).fill('x') };
    const { error } = unitSchema.validate(u);
    expect(error).toBeDefined();
  });
});

// ── updateBuildingSchema ──
describe('updateBuildingSchema', () => {
  test('accepts partial update with just name', () => {
    const { error } = updateBuildingSchema.validate({ name: 'New Name' });
    expect(error).toBeUndefined();
  });

  test('accepts empty object', () => {
    const { error } = updateBuildingSchema.validate({});
    expect(error).toBeUndefined();
  });

  test('still validates field constraints', () => {
    const { error } = updateBuildingSchema.validate({ name: 'A' });
    expect(error).toBeDefined();
  });

  test('accepts partial properties update', () => {
    const { error } = updateBuildingSchema.validate({ properties: { gym: true } });
    expect(error).toBeUndefined();
  });

  test('allows setting managerId to null', () => {
    const { error } = updateBuildingSchema.validate({ managerId: null });
    expect(error).toBeUndefined();
  });
});

// ── updateUnitSchema ──
describe('updateUnitSchema', () => {
  test('accepts partial update with just rent', () => {
    const { error } = updateUnitSchema.validate({ rent: 900 });
    expect(error).toBeUndefined();
  });

  test('accepts empty object', () => {
    const { error } = updateUnitSchema.validate({});
    expect(error).toBeUndefined();
  });

  test('still validates field constraints', () => {
    const { error } = updateUnitSchema.validate({ rent: -5 });
    expect(error).toBeDefined();
  });

  test('accepts partial features update', () => {
    const { error } = updateUnitSchema.validate({ features: { balcony: true } });
    expect(error).toBeUndefined();
  });

  test('allows setting tenantName to empty string', () => {
    const { error } = updateUnitSchema.validate({ tenantName: '' });
    expect(error).toBeUndefined();
  });
});
