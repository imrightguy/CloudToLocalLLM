jest.mock('../src/services/photo.service', () => ({
  listPropertyPhotos: jest.fn(),
  createPropertyPhoto: jest.fn(),
  getPropertyPhotoById: jest.fn(),
}));

jest.mock('../src/services/photo-storage.service', () => ({
  storePropertyPhotoFile: jest.fn(),
  deleteStoredPropertyPhotoFile: jest.fn(),
}));

const photoService = require('../src/services/photo.service');
const photoStorage = require('../src/services/photo-storage.service');
const {
  uploadPropertyPhoto,
  downloadPropertyPhotoFile,
} = require('../src/controllers/photo.controller');

function makeRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.type = jest.fn().mockReturnValue(res);
  res.setHeader = jest.fn();
  res.sendFile = jest.fn((filePath, options, callback) => callback());
  return res;
}

describe('photo.controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('stores a binary upload and creates a downloadable photo record', async () => {
    photoStorage.storePropertyPhotoFile.mockResolvedValue({
      storageProvider: 'local_fs',
      storageRoot: '/tmp/property-photos',
      storageKey: 'company/building/unit/maintenance/photo-1.jpg',
      storagePath: '/tmp/property-photos/company/building/unit/maintenance/photo-1.jpg',
      storedFileName: 'photo-1.jpg',
      originalFileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      fileSizeBytes: 1234,
    });
    photoService.createPropertyPhoto.mockResolvedValue({ id: 'photo-1' });

    const req = {
      params: { companyId: 'company-1' },
      body: {
        buildingId: 'building-1',
        unitId: 'unit-1',
        roomContext: 'Salon',
        useCase: 'maintenance',
        displayOrder: 2,
        documentRefId: 'doc-1',
        capturedAt: '2026-05-06T10:00:00.000Z',
        metadata: { source: 'mobile' },
      },
      photoUpload: {
        filepath: '/tmp/upload.tmp',
        originalFilename: 'photo.jpg',
        mimetype: 'image/jpeg',
        size: 1234,
      },
      user: { id: 'user-1' },
    };
    const res = makeRes();

    await uploadPropertyPhoto(req, res);

    expect(photoStorage.storePropertyPhotoFile).toHaveBeenCalledWith(expect.objectContaining({
      companyId: 'company-1',
      buildingId: 'building-1',
      unitId: 'unit-1',
      useCase: 'maintenance',
    }));
    const createCall = photoService.createPropertyPhoto.mock.calls[0][0];
    expect(createCall).toEqual(expect.objectContaining({
      companyId: 'company-1',
      buildingId: 'building-1',
      unitId: 'unit-1',
      roomContext: 'Salon',
      useCase: 'maintenance',
      displayOrder: 2,
      fileName: 'photo.jpg',
      storedFileName: 'photo-1.jpg',
      storageProvider: 'local_fs',
      storageKey: 'company/building/unit/maintenance/photo-1.jpg',
      storagePath: '/tmp/property-photos/company/building/unit/maintenance/photo-1.jpg',
      fileSizeBytes: 1234,
      mimeType: 'image/jpeg',
      uploadedByUserId: 'user-1',
      metadata: { source: 'mobile' },
    }));
    expect(createCall.id).toEqual(expect.any(String));
    expect(createCall.url).toBe(`/api/companies/company-1/photos/${createCall.id}/file`);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Photo file uploaded successfully',
    }));
  });

  it('streams the stored file for the company-scoped download route', async () => {
    photoService.getPropertyPhotoById.mockResolvedValue({
      id: 'photo-1',
      companyId: 'company-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      storagePath: '/tmp/property-photos/photo.jpg',
    });

    const req = {
      params: { companyId: 'company-1', photoId: 'photo-1' },
    };
    const res = makeRes();

    await downloadPropertyPhotoFile(req, res);

    expect(photoService.getPropertyPhotoById).toHaveBeenCalledWith({
      companyId: 'company-1',
      photoId: 'photo-1',
    });
    expect(res.type).toHaveBeenCalledWith('image/jpeg');
    expect(res.setHeader).toHaveBeenCalledWith('Content-Disposition', 'inline; filename="photo.jpg"');
    expect(res.sendFile).toHaveBeenCalledWith('/tmp/property-photos/photo.jpg', expect.any(Function));
  });
});
