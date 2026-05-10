jest.mock('../../src/services/maintenance-command-center.service', () => ({
  getMaintenanceCommandCenter: jest.fn(),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ error: jest.fn() })),
}));

const { getMaintenanceCommandCenter } = require('../../src/services/maintenance-command-center.service');
const renovationController = require('../../src/controllers/renovation.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

describe('renovation controller dashboard', () => {
  it('adapts the maintenance command center payload to the daily tasks dashboard shape', async () => {
    getMaintenanceCommandCenter.mockResolvedValue({
      summary: {
        propertyCount: 2,
        renovationCount: 5,
        blockedCount: 1,
        readyCount: 2,
        overdueTaskCount: 3,
        dueSoonTaskCount: 4,
        openOrderCount: 1,
        pendingIntakeCount: 2,
        dispatchableEmployeeCount: 3,
        tenantMessageSentCount: 4,
        tenantMessageFailedCount: 1,
        tenantMessagePendingCount: 2,
      },
      properties: [
        {
          buildingName: 'Place du Parc',
          unitCount: 10,
          renovationCount: 2,
          blockedCount: 1,
          readyCount: 1,
          overdueTaskCount: 3,
          dueSoonTaskCount: 4,
        },
      ],
      backlog: [
        {
          id: 'reno-1',
          unitId: 'unit-1',
          buildingId: 'building-1',
          unitLabel: '304',
          buildingName: 'Place du Parc',
          phase: 'blocked',
          readiness: '71 % prêt',
          taskCount: 8,
          doneCount: 5,
          blockerCount: 1,
          overdueTaskCount: 1,
          dueSoonTaskCount: 1,
          nextStep: 'Peinture finale et inspection cuisine',
          updatedAt: '2026-05-06T00:20:00.000Z',
          blockerNote: 'Attente d’un luminaire pour le salon',
          nextDueAt: '2026-05-07T00:00:00.000Z',
          assignedEmployeeLabel: 'Alice Smith',
          tasks: [{ title: 'Peinture', status: 'todo', dueDate: '2026-05-06T00:00:00.000Z', assigneeName: 'Alice Smith' }],
        },
      ],
      reviewQueue: { summary: {}, recommendations: [] },
      asOf: '2026-05-06T00:00:00.000Z',
    });

    const req = { query: { limit: '12' } };
    const res = mockRes();

    await renovationController.getDashboard(req, res);

    expect(getMaintenanceCommandCenter).toHaveBeenCalledWith({ buildingId: null, limit: '12' });
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Tableau des tâches du jour récupéré avec succès',
      data: expect.objectContaining({
        summary: expect.objectContaining({
          activeApartments: 1,
          readyApartments: 0,
          overdueTasks: 3,
          dueSoonTasks: 4,
          properties: 2,
        }),
        apartments: expect.arrayContaining([
          expect.objectContaining({ id: 'reno-1', unitLabel: '304' }),
        ]),
        byBuilding: expect.arrayContaining([
          expect.objectContaining({
            buildingName: 'Place du Parc',
            apartmentCount: 10,
            overdueTaskCount: 3,
            dueSoonTaskCount: 4,
          }),
        ]),
        asOf: '2026-05-06T00:00:00.000Z',
      }),
    }));
  });
});
