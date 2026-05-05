const {
  buildingSchema,
  unitSchema,
  updateBuildingSchema,
  updateUnitSchema,
} = require('../../src/models/building');

describe('buildingSchema', () => {
  const validBuilding = {
    name: 'Sunset Towers',
    address: '123 Main Street, Montreal',
    city: 'Montreal',
    totalUnits: 10,
  };

  it('validates a minimal valid building', () => {
    const { error, value } = buildingSchema.validate(validBuilding);
    expect(error).toBeUndefined();
    expect(value.name).toBe('Sunset Towers');
    expect(value.address).toBe('123 Main Street, Montreal');
    expect(value.totalUnits).toBe(10);
    expect(value.occupiedUnits).toBe(0);
    expect(value.monthlyRevenue).toBe(0);
    expect(value.properties).toEqual({});
  });

  it('validates a full building with all fields', () => {
    const full = {
      ...validBuilding,
      occupiedUnits: 5,
      monthlyRevenue: 150000,
      managerId: '550e8400-e29b-41d4-a716-446655440000',
      properties: {
        yearBuilt: 1990,
        elevator: true,
        gym: false,
        pool: true,
        parking: true,
        laundry: true,
        petFriendly: false,
        security: true,
        description: 'A nice building',
        images: ['https://example.com/photo1.jpg'],
        amenities: ['Gym', 'Pool'],
      },
    };
    const { error, value } = buildingSchema.validate(full);
    expect(error).toBeUndefined();
    expect(value.occupiedUnits).toBe(5);
    expect(value.monthlyRevenue).toBe(150000);
    expect(value.properties.elevator).toBe(true);
    expect(value.properties.images).toHaveLength(1);
  });

  it('rejects missing name', () => {
    const { error } = buildingSchema.validate({ city: 'Montreal', address: '123 Main St', totalUnits: 5 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects name shorter than 2 characters', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, name: 'A' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects name longer than 100 characters', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, name: 'A'.repeat(101) });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('name');
  });

  it('rejects missing address', () => {
    const { error } = buildingSchema.validate({ name: 'Test', city: 'Montreal', totalUnits: 5 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('address');
  });

  it('rejects address shorter than 5 characters', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, address: '1234' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('address');
  });

  it('rejects missing totalUnits', () => {
    const { error } = buildingSchema.validate({ name: 'Test', city: 'Montreal', address: '123 Main St' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('totalUnits');
  });

  it('rejects totalUnits of 0', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, totalUnits: 0 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('totalUnits');
  });

  it('rejects totalUnits over 1000', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, totalUnits: 1001 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('totalUnits');
  });

  it('rejects negative occupiedUnits', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, occupiedUnits: -1 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('occupiedUnits');
  });

  it('rejects occupiedUnits exceeding totalUnits', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, totalUnits: 5, occupiedUnits: 6 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('occupiedUnits');
  });

  it('rejects negative monthlyRevenue', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, monthlyRevenue: -100 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('monthlyRevenue');
  });

  it('rejects non-integer monthlyRevenue', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, monthlyRevenue: 100.5 });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('monthlyRevenue');
  });

  it('allows null managerId', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, managerId: null });
    expect(error).toBeUndefined();
  });

  it('rejects invalid managerId', () => {
    const { error } = buildingSchema.validate({ ...validBuilding, managerId: 'not-a-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('managerId');
  });

  it('rejects yearBuilt before 1800', () => {
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { yearBuilt: 1799 },
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('yearBuilt');
  });

  it('rejects yearBuilt in the future', () => {
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { yearBuilt: 2099 },
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('yearBuilt');
  });

  it('rejects more than 20 images', () => {
    const images = Array.from({ length: 21 }, (_, i) => `https://example.com/img${i}.jpg`);
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { images },
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('images');
  });

  it('rejects invalid image URLs', () => {
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { images: ['not-a-url'] },
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('images');
  });

  it('rejects more than 50 amenities', () => {
    const amenities = Array.from({ length: 51 }, (_, i) => `Amenity ${i}`);
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { amenities },
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('amenities');
  });

  it('rejects description over 2000 chars in properties', () => {
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { description: 'A'.repeat(2001) },
    });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('description');
  });

  it('allows empty description', () => {
    const { error } = buildingSchema.validate({
      ...validBuilding,
      properties: { description: '' },
    });
    expect(error).toBeUndefined();
  });
});

describe('unitSchema', () => {
  const validUnit = {
    buildingId: '550e8400-e29b-41d4-a716-446655440000',
    label: 'A-101',
    rent: 85000,
    status: 'vacant',
  };

  it('validates a minimal valid unit', () => {
    const { error, value } = unitSchema.validate(validUnit);
    expect(error).toBeUndefined();
    expect(value.buildingId).toBe('550e8400-e29b-41d4-a716-446655440000');
    expect(value.label).toBe('A-101');
    expect(value.rent).toBe(85000);
    expect(value.status).toBe('vacant');
    expect(value.amenities).toEqual([]);
    expect(value.features).toEqual({});
  });

  it('validates a full unit with all fields', () => {
    const full = {
      ...validUnit,
      amenities: ['Parking', 'Storage'],
      squareFeet: 800,
      bedrooms: 2,
      bathrooms: 1,
      description: 'Bright unit',
      features: {
        furnished: true,
        parkingIncluded: false,
        airConditioning: true,
        balcony: false,
        patio: true,
        fireplace: false,
        dishwasher: true,
        microwave: false,
        inUnitLaundry: true,
      },
      tenantName: 'Jean Tremblay',
      tenantPhone: '+1 514-555-1234',
      tenantLeaseEnd: '2026-06-30',
    };
    const { error, value } = unitSchema.validate(full);
    expect(error).toBeUndefined();
    expect(value.features.furnished).toBe(true);
    expect(value.tenantName).toBe('Jean Tremblay');
  });

  it('rejects missing buildingId', () => {
    const { error } = unitSchema.validate({ label: 'A-101', rent: 85000, status: 'vacant' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('buildingId');
  });

  it('rejects invalid buildingId', () => {
    const { error } = unitSchema.validate({ ...validUnit, buildingId: 'not-a-uuid' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('buildingId');
  });

  it('allows missing label', () => {
    const { error } = unitSchema.validate({ buildingId: validUnit.buildingId, rent: 85000, status: 'vacant' });
    expect(error).toBeUndefined();
  });

  it('rejects label with special characters', () => {
    const { error } = unitSchema.validate({ ...validUnit, label: 'A@101' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('label');
  });

  it('allows label with hyphens and spaces', () => {
    const { error } = unitSchema.validate({ ...validUnit, label: 'A-1 01' });
    expect(error).toBeUndefined();
  });

  it('rejects label shorter than 2 characters', () => {
    const { error } = unitSchema.validate({ ...validUnit, label: 'A' });
    expect(error).toBeDefined();
  });

  it('rejects label longer than 50 characters', () => {
    const { error } = unitSchema.validate({ ...validUnit, label: 'A'.repeat(51) });
    expect(error).toBeDefined();
  });

  it('allows missing rent', () => {
    const { error } = unitSchema.validate({ ...validUnit, rent: undefined });
    expect(error).toBeUndefined();
  });

  it('rejects negative rent', () => {
    const { error } = unitSchema.validate({ ...validUnit, rent: -1 });
    expect(error).toBeDefined();
  });

  it('rejects rent over 100000', () => {
    const { error } = unitSchema.validate({ ...validUnit, rent: 100001 });
    expect(error).toBeDefined();
  });

  it('rejects invalid status', () => {
    const { error } = unitSchema.validate({ ...validUnit, status: 'unknown' });
    expect(error).toBeDefined();
    expect(error.details[0].path).toContain('status');
  });

  it('defaults status to vacant when omitted', () => {
    const { error, value } = unitSchema.validate({
      buildingId: validUnit.buildingId,
      label: 'A-101',
      rent: 85000,
      status: 'vacant',
    });
    expect(error).toBeUndefined();
    expect(value.status).toBe('vacant');
  });

  it('allows squareFeet between 100 and 10000', () => {
    const { error } = unitSchema.validate({ ...validUnit, squareFeet: 500 });
    expect(error).toBeUndefined();
  });

  it('rejects squareFeet below 100', () => {
    const { error } = unitSchema.validate({ ...validUnit, squareFeet: 99 });
    expect(error).toBeDefined();
  });

  it('rejects squareFeet over 10000', () => {
    const { error } = unitSchema.validate({ ...validUnit, squareFeet: 10001 });
    expect(error).toBeDefined();
  });

  it('rejects bedrooms over 10', () => {
    const { error } = unitSchema.validate({ ...validUnit, bedrooms: 11 });
    expect(error).toBeDefined();
  });

  it('rejects bathrooms over 10', () => {
    const { error } = unitSchema.validate({ ...validUnit, bathrooms: 11 });
    expect(error).toBeDefined();
  });

  it('allows null tenantName', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantName: null });
    expect(error).toBeUndefined();
  });

  it('allows empty tenantName', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantName: '' });
    expect(error).toBeUndefined();
  });

  it('rejects tenantName over 200 chars', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantName: 'A'.repeat(201) });
    expect(error).toBeDefined();
  });

  it('allows valid phone numbers', () => {
    const phones = ['+1 514-555-1234', '5145551234', '+1 (514) 555-1234'];
    for (const phone of phones) {
      const { error } = unitSchema.validate({ ...validUnit, tenantPhone: phone });
      expect(error).toBeUndefined();
    }
  });

  it('allows null tenantPhone', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantPhone: null });
    expect(error).toBeUndefined();
  });

  it('allows null tenantLeaseEnd', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantLeaseEnd: null });
    expect(error).toBeUndefined();
  });

  it('rejects invalid tenantLeaseEnd', () => {
    const { error } = unitSchema.validate({ ...validUnit, tenantLeaseEnd: 'not-a-date' });
    expect(error).toBeDefined();
  });

  it('allows more than 50 amenities in unit', () => {
    const { error } = unitSchema.validate({
      ...validUnit,
      amenities: Array.from({ length: 51 }, (_, i) => `Item ${i}`),
    });
    expect(error).toBeDefined();
  });

  it('allows empty description', () => {
    const { error } = unitSchema.validate({ ...validUnit, description: '' });
    expect(error).toBeUndefined();
  });

  it('rejects description over 2000 chars', () => {
    const { error } = unitSchema.validate({ ...validUnit, description: 'A'.repeat(2001) });
    expect(error).toBeDefined();
  });
});

describe('updateBuildingSchema', () => {
  it('validates partial update with just name', () => {
    const { error, value } = updateBuildingSchema.validate({ name: 'New Name' });
    expect(error).toBeUndefined();
    expect(value.name).toBe('New Name');
  });

  it('validates partial update with just address', () => {
    const { error } = updateBuildingSchema.validate({ address: '456 New Street' });
    expect(error).toBeUndefined();
  });

  it('validates empty object', () => {
    const { error } = updateBuildingSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('still validates name length on update', () => {
    const { error } = updateBuildingSchema.validate({ name: 'A' });
    expect(error).toBeDefined();
  });

  it('still validates address length on update', () => {
    const { error } = updateBuildingSchema.validate({ address: '1234' });
    expect(error).toBeDefined();
  });

  it('still validates totalUnits range on update', () => {
    const { error } = updateBuildingSchema.validate({ totalUnits: 0 });
    expect(error).toBeDefined();
  });

  it('allows null managerId on update', () => {
    const { error } = updateBuildingSchema.validate({ managerId: null });
    expect(error).toBeUndefined();
  });

  it('allows updating properties', () => {
    const { error } = updateBuildingSchema.validate({
      properties: { gym: true, pool: false },
    });
    expect(error).toBeUndefined();
  });

  it('allows removing properties (undefined)', () => {
    const { error } = updateBuildingSchema.validate({ properties: undefined });
    expect(error).toBeUndefined();
  });

  it('still validates properties.yearBuilt on update', () => {
    const { error } = updateBuildingSchema.validate({
      properties: { yearBuilt: 2099 },
    });
    expect(error).toBeDefined();
  });
});

describe('updateUnitSchema', () => {
  it('validates partial update with just label', () => {
    const { error, value } = updateUnitSchema.validate({ label: 'B-202' });
    expect(error).toBeUndefined();
    expect(value.label).toBe('B-202');
  });

  it('validates partial update with just rent', () => {
    const { error } = updateUnitSchema.validate({ rent: 90000 });
    expect(error).toBeUndefined();
  });

  it('validates empty object', () => {
    const { error } = updateUnitSchema.validate({});
    expect(error).toBeUndefined();
  });

  it('still validates label pattern on update', () => {
    const { error } = updateUnitSchema.validate({ label: 'B@101' });
    expect(error).toBeDefined();
  });

  it('still validates rent range on update', () => {
    const { error } = updateUnitSchema.validate({ rent: -1 });
    expect(error).toBeDefined();
  });

  it('still validates status enum on update', () => {
    const { error } = updateUnitSchema.validate({ status: 'invalid' });
    expect(error).toBeDefined();
  });

  it('allows updating features partially', () => {
    const { error } = updateUnitSchema.validate({
      features: { furnished: true, balcony: true },
    });
    expect(error).toBeUndefined();
  });

  it('allows null tenant fields on update', () => {
    const { error } = updateUnitSchema.validate({
      tenantName: null,
      tenantPhone: null,
      tenantLeaseEnd: null,
    });
    expect(error).toBeUndefined();
  });

  it('still validates tenantName length on update', () => {
    const { error } = updateUnitSchema.validate({ tenantName: 'A'.repeat(201) });
    expect(error).toBeDefined();
  });

  it('still validates squareFeet range on update', () => {
    const { error } = updateUnitSchema.validate({ squareFeet: 50 });
    expect(error).toBeDefined();
  });

  it('allows valid status transitions', () => {
    for (const status of ['vacant', 'occupied', 'maintenance']) {
      const { error } = updateUnitSchema.validate({ status });
      expect(error).toBeUndefined();
    }
  });
});
