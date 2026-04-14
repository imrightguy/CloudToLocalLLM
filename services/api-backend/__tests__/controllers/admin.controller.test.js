jest.mock('../../src/database/connection', () => ({
  db: {
    execute: jest.fn().mockResolvedValue(undefined),
  },
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

jest.mock('../../scripts/seed-demo', () => ({
  seedDemoData: jest.fn().mockResolvedValue(undefined),
}));

const adminController = require('../../src/controllers/admin.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

describe('Admin Controller', () => {
  describe('seedDemo', () => {
    it('should return 200 on successful seed', async () => {
      const req = {};
      const res = mockRes();
      const { seedDemoData } = require('../../scripts/seed-demo');

      await adminController.seedDemo(req, res);

      expect(seedDemoData).toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Demo data seeded successfully',
        }),
      );
    });

    it('should return 500 when seeding fails', async () => {
      const req = {};
      const res = mockRes();
      const { seedDemoData } = require('../../scripts/seed-demo');
      seedDemoData.mockRejectedValueOnce(new Error('DB connection failed'));

      await adminController.seedDemo(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: false,
          error: expect.objectContaining({ code: 'SEED_FAILED' }),
        }),
      );
    });
  });

  describe('clearDemo', () => {
    it('should return 200 on successful clear', async () => {
      const req = {};
      const res = mockRes();

      await adminController.clearDemo(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Demo data cleared successfully',
        }),
      );
    });

    it('should return 200 even when individual table deletes fail', async () => {
      const req = {};
      const res = mockRes();
      const { db } = require('../../src/database/connection');
      db.execute.mockRejectedValueOnce(new Error('table not found'));

      await adminController.clearDemo(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Demo data cleared successfully',
        }),
      );
    });
  });
});
