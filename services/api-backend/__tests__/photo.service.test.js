jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn(),
    insert: jest.fn(),
  },
}));

const { db } = require('../src/database/connection');
const { listPropertyPhotos, createPropertyPhoto, getPropertyPhotoById } = require('../src/services/photo.service');

function makeSelectForCount(total) {
  return {
    from: jest.fn(() => ({
      where: jest.fn(() => Promise.resolve([{ count: total }])),
    })),
  };
}

function makeSelectForRows(rows) {
  return {
    from: jest.fn(() => ({
      where: jest.fn(() => ({
        orderBy: jest.fn(() => ({
          limit: jest.fn(() => ({
            offset: jest.fn(() => Promise.resolve(rows)),
          })),
        })),
      })),
    })),
  };
}

function makeSelectForSingleRow(row) {
  return {
    from: jest.fn(() => ({
      where: jest.fn(() => ({
        limit: jest.fn(() => Promise.resolve([row])),
      })),
    })),
  };
}

function makeInsertChain(row) {
  return {
    values: jest.fn(() => ({
      returning: jest.fn(() => Promise.resolve([row])),
    })),
  };
}

describe('photo.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('lists company-scoped photo records with pagination metadata', async () => {
    const rows = [
      {
        id: 'photo-1',
        companyId: 'company-1',
        buildingId: 'building-1',
        unitId: 'unit-1',
        useCase: 'maintenance',
        displayOrder: 1,
      },
      {
        id: 'photo-2',
        companyId: 'company-1',
        buildingId: 'building-1',
        unitId: null,
        useCase: 'maintenance',
        displayOrder: 2,
      },
    ];

    let selectCalls = 0;
    db.select.mockImplementation(() => {
      selectCalls += 1;
      if (selectCalls === 1) {
        return makeSelectForCount(2);
      }
      return makeSelectForRows(rows);
    });

    const result = await listPropertyPhotos({
      companyId: 'company-1',
      buildingId: 'building-1',
      useCase: 'maintenance',
      page: 1,
      limit: 20,
    });

    expect(result.rows).toEqual(rows);
    expect(result.metadata).toMatchObject({
      total: 2,
      page: 1,
      limit: 20,
      totalPages: 1,
      hasMore: false,
    });
  });

  it('creates a photo record after validating the building and unit relationship', async () => {
    const created = {
      id: 'photo-3',
      companyId: 'company-1',
      buildingId: 'building-1',
      unitId: 'unit-1',
      roomContext: 'Salon',
      useCase: 'marketing',
      displayOrder: 0,
      fileName: 'living-room.jpg',
      storedFileName: 'living-room-123.jpg',
      storageProvider: 'local_fs',
      storageKey: 'company-1/buildings/building-1/units/unit-1/marketing/living-room-123.jpg',
      storagePath: '/tmp/property-photos/company-1/buildings/building-1/units/unit-1/marketing/living-room-123.jpg',
      fileSizeBytes: 42,
      url: '/api/companies/company-1/photos/photo-3/file',
    };

    let selectCalls = 0;
    db.select.mockImplementation(() => {
      selectCalls += 1;
      if (selectCalls === 1) {
        return makeSelectForSingleRow({ id: 'building-1' });
      }
      if (selectCalls === 2) {
        return makeSelectForSingleRow({ id: 'unit-1', buildingId: 'building-1' });
      }
      throw new Error(`Unexpected select call ${selectCalls}`);
    });
    db.insert.mockReturnValue(makeInsertChain(created));

    const result = await createPropertyPhoto({
      companyId: 'company-1',
      buildingId: 'building-1',
      unitId: 'unit-1',
      roomContext: 'Salon',
      useCase: 'marketing',
      displayOrder: 0,
      fileName: 'living-room.jpg',
      mimeType: 'image/jpeg',
      url: 'https://example.com/living-room.jpg',
      capturedAt: new Date('2026-05-06T10:00:00.000Z'),
      uploadedByUserId: 'user-1',
      metadata: { source: 'mobile' },
    });

    expect(result).toEqual(created);
    expect(db.insert).toHaveBeenCalled();
  });

  it('returns the company-scoped photo record for secure file downloads', async () => {
    const photo = {
      id: 'photo-4',
      companyId: 'company-1',
      storagePath: '/tmp/property-photos/photo-4.jpg',
    };

    db.select.mockReturnValue(makeSelectForSingleRow(photo));

    const result = await getPropertyPhotoById({
      companyId: 'company-1',
      photoId: 'photo-4',
    });

    expect(result).toEqual(photo);
  });

  it('rejects photo records whose unit does not belong to the building', async () => {
    let selectCalls = 0;
    db.select.mockImplementation(() => {
      selectCalls += 1;
      if (selectCalls === 1) {
        return makeSelectForSingleRow({ id: 'building-1' });
      }
      if (selectCalls === 2) {
        return makeSelectForSingleRow({ id: 'unit-1', buildingId: 'building-2' });
      }
      throw new Error(`Unexpected select call ${selectCalls}`);
    });

    await expect(createPropertyPhoto({
      companyId: 'company-1',
      buildingId: 'building-1',
      unitId: 'unit-1',
      useCase: 'inventory',
      displayOrder: 0,
      fileName: 'inventory.jpg',
      url: 'https://example.com/inventory.jpg',
    })).rejects.toMatchObject({
      statusCode: 409,
      code: 'PHOTO_UNIT_BUILDING_MISMATCH',
    });
  });
});
