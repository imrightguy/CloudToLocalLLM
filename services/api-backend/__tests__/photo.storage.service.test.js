const fs = require('fs/promises');
const os = require('os');
const path = require('path');

const {
  storePropertyPhotoFile,
  deleteStoredPropertyPhotoFile,
} = require('../src/services/photo-storage.service');

describe('photo-storage.service', () => {
  let tempDir;

  beforeEach(async () => {
    tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'property-photo-storage-'));
    process.env.PROPERTY_PHOTO_STORAGE_DIR = tempDir;
  });

  afterEach(async () => {
    delete process.env.PROPERTY_PHOTO_STORAGE_DIR;
    if (tempDir) {
      await fs.rm(tempDir, { recursive: true, force: true });
    }
  });

  it('stores the uploaded file beneath a company-scoped storage key', async () => {
    const sourcePath = path.join(tempDir, 'source.jpg');
    await fs.writeFile(sourcePath, 'binary-photo');

    const result = await storePropertyPhotoFile({
      file: {
        filepath: sourcePath,
        originalFilename: 'living room.jpg',
        mimetype: 'image/jpeg',
        size: 12,
      },
      companyId: 'company-1',
      buildingId: 'building-1',
      unitId: 'unit-1',
      useCase: 'maintenance',
    });

    expect(result.storageProvider).toBe('local_fs');
    expect(result.storageKey).toContain('company-1/buildings/building-1/units/unit-1/maintenance/');
    expect(result.storagePath.startsWith(tempDir)).toBe(true);
    expect(result.mimeType).toBe('image/jpeg');
    expect(result.fileSizeBytes).toBe(12);
    expect(await fs.readFile(result.storagePath, 'utf8')).toBe('binary-photo');
  });

  it('deletes a stored file when cleanup is requested', async () => {
    const storedPath = path.join(tempDir, 'stored', 'photo.jpg');
    await fs.mkdir(path.dirname(storedPath), { recursive: true });
    await fs.writeFile(storedPath, 'photo');

    await expect(deleteStoredPropertyPhotoFile(storedPath)).resolves.toBe(true);
    await expect(fs.access(storedPath)).rejects.toBeDefined();
  });
});
