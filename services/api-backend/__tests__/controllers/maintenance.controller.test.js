jest.mock('../../src/services/maintenance-command-center.service', () => ({
  getMaintenanceCommandCenter: jest.fn(),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

const { getMaintenanceCommandCenter } = require('../../src/services/maintenance-command-center.service');
const maintenanceController = require('../../src/controllers/maintenance.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe('maintenance controller', () => {
  it('returns the maintenance command center payload', async () => {
    getMaintenanceCommandCenter.mockResolvedValue({
      summary: { propertyCount: 1 },
      properties: [],
      backlog: [],
      tenantMessages: [],
      asOf: '2026-05-04T12:00:00.000Z',
    });

    const res = mockRes();
    await maintenanceController.getCommandCenter({ query: {} }, res);

    expect(getMaintenanceCommandCenter).toHaveBeenCalledWith({ buildingId: null, limit: 12 });
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ summary: { propertyCount: 1 } }),
    }));
  });

  it('returns a 500 when the service fails', async () => {
    getMaintenanceCommandCenter.mockRejectedValue(new Error('boom'));

    const res = mockRes();
    await maintenanceController.getCommandCenter({ query: { buildingId: 'building-1', limit: '5' } }, res);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      error: expect.objectContaining({ code: 'MAINTENANCE_COMMAND_CENTER_FAILED' }),
    }));
  });
});
