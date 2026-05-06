const { getMaintenanceCommandCenter } = require('../../src/services/maintenance-command-center.service');

jest.mock('../../src/database/connection', () => ({
  db: {
    select: jest.fn(),
  },
}));

const { db } = require('../../src/database/connection');

const makeQueryChain = (rows) => {
  const chain = {};
  for (const method of ['from', 'where', 'orderBy', 'limit', 'leftJoin', 'innerJoin']) {
    chain[method] = jest.fn().mockReturnValue(chain);
  }
  chain.then = (onFulfilled, onRejected) => Promise.resolve(rows).then(onFulfilled, onRejected);
  chain.catch = (onRejected) => Promise.resolve(rows).catch(onRejected);
  return chain;
};

describe('maintenance-command-center.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    db.select.mockImplementation(() => makeQueryChain([]));
  });

  it('returns an empty command center when there is no maintenance data', async () => {
    const asOf = new Date('2026-05-06T02:11:20.000Z');

    const result = await getMaintenanceCommandCenter({ asOf });

    expect(result).toEqual({
      summary: {
        propertyCount: 0,
        renovationCount: 0,
        blockedCount: 0,
        readyCount: 0,
        overdueTaskCount: 0,
        dueSoonTaskCount: 0,
        openOrderCount: 0,
        pendingIntakeCount: 0,
        dispatchableEmployeeCount: 0,
        tenantMessageSentCount: 0,
        tenantMessageFailedCount: 0,
        tenantMessagePendingCount: 0,
      },
      properties: [],
      backlog: [],
      tenantMessages: [],
      reviewQueue: {
        summary: {
          totalRecommendations: 0,
          urgentCount: 0,
          warningCount: 0,
          infoCount: 0,
          draftSmsCount: 0,
        },
        recommendations: [],
        asOf: asOf.toISOString(),
      },
      asOf: asOf.toISOString(),
    });

    expect(db.select).toHaveBeenCalledTimes(9);
  });

  it('filters the command center to a single building and caps the backlog size', async () => {
    const asOf = new Date('2026-05-06T02:11:20.000Z');

    db.select
      .mockImplementationOnce(() => makeQueryChain([
        { id: 'building-1', name: 'Place du Parc', isActive: true },
        { id: 'building-2', name: 'Ateliers Nord', isActive: true },
      ]))
      .mockImplementationOnce(() => makeQueryChain([
        { id: 'unit-1', buildingId: 'building-1', label: '304', tenantPhone: '(514) 555-0101', isActive: true },
        { id: 'unit-2', buildingId: 'building-2', label: '118', tenantPhone: null, isActive: true },
      ]))
      .mockImplementationOnce(() => makeQueryChain([
        {
          id: 'reno-1',
          unitId: 'unit-1',
          buildingId: 'building-1',
          status: 'active',
          readinessState: 'in_progress',
          updatedAt: new Date('2026-05-05T12:00:00.000Z'),
          targetEndDate: new Date('2026-05-15T00:00:00.000Z'),
          notes: 'Need more tile',
          isActive: true,
        },
        {
          id: 'reno-2',
          unitId: 'unit-2',
          buildingId: 'building-2',
          status: 'active',
          readinessState: 'in_progress',
          updatedAt: new Date('2026-05-04T12:00:00.000Z'),
          targetEndDate: new Date('2026-05-12T00:00:00.000Z'),
          notes: 'Hidden by building filter',
          isActive: true,
        },
      ]))
      .mockImplementationOnce(() => makeQueryChain([
        {
          id: 'task-1',
          renovationRecordId: 'reno-1',
          title: 'Peinture finale',
          status: 'blocked',
          dueDate: new Date('2026-05-04T00:00:00.000Z'),
          assigneeEmployeeId: 'emp-1',
          createdAt: new Date('2026-05-01T00:00:00.000Z'),
          isActive: true,
        },
        {
          id: 'task-2',
          renovationRecordId: 'reno-2',
          title: 'Nettoyage final',
          status: 'done',
          dueDate: new Date('2026-05-08T00:00:00.000Z'),
          assigneeEmployeeId: null,
          createdAt: new Date('2026-05-03T00:00:00.000Z'),
          isActive: true,
        },
      ]))
      .mockImplementationOnce(() => makeQueryChain([
        {
          id: 'order-1',
          renovationRecordId: 'reno-1',
          itemName: 'Luminaire',
          status: 'partially_received',
          expectedAt: new Date('2026-05-08T00:00:00.000Z'),
          isActive: true,
        },
        {
          id: 'order-2',
          renovationRecordId: 'reno-2',
          itemName: 'Peinture',
          status: 'received',
          expectedAt: new Date('2026-05-06T00:00:00.000Z'),
          isActive: true,
        },
      ]))
      .mockImplementationOnce(() => makeQueryChain([
        {
          id: 'intake-1',
          renovationRecordId: 'reno-1',
          messageKind: 'missing_material',
          status: 'new',
          summary: 'Need 2 more boxes of tile',
          messageBody: 'Need 2 more boxes of tile',
          receivedAt: new Date('2026-05-05T08:00:00.000Z'),
          isActive: true,
        },
      ]))
      .mockImplementationOnce(() => makeQueryChain([
        { id: 'emp-1', firstName: 'Alice', lastName: 'Smith', isActive: true },
      ]))
      .mockImplementationOnce(() => makeQueryChain([
        {
          id: 'assignment-1',
          employeeId: 'emp-1',
          buildingId: 'building-1',
          role: 'primary',
          isActive: true,
        },
      ]))
      .mockImplementationOnce(() => makeQueryChain([]));

    const result = await getMaintenanceCommandCenter({ buildingId: 'building-1', limit: 1, asOf });

    expect(result.summary).toEqual(expect.objectContaining({
      propertyCount: 1,
      renovationCount: 1,
      blockedCount: 1,
      readyCount: 0,
      openOrderCount: 1,
      pendingIntakeCount: 1,
    }));
    expect(result.properties).toHaveLength(1);
    expect(result.properties[0]).toEqual(expect.objectContaining({
      buildingId: 'building-1',
      buildingName: 'Place du Parc',
      renovationCount: 1,
      blockedCount: 1,
    }));
    expect(result.backlog).toHaveLength(1);
    expect(result.backlog[0]).toEqual(expect.objectContaining({
      buildingId: 'building-1',
      unitLabel: '304',
      phase: 'blocked',
      blockerNote: 'Need 2 more boxes of tile',
      assignedEmployeeLabel: 'Alice Smith',
    }));
    expect(result.reviewQueue.summary).toEqual(expect.objectContaining({
      totalRecommendations: 3,
      urgentCount: 1,
      warningCount: 1,
      infoCount: 1,
      draftSmsCount: 1,
    }));
    expect(result.reviewQueue.recommendations.map((item) => item.kind)).toEqual([
      'blocker_follow_up',
      'capacity_gap',
      'tenant_sms_draft',
    ]);
    expect(result.reviewQueue.recommendations[2]).toEqual(expect.objectContaining({
      draftSms: expect.stringContaining('unité 304'),
    }));
    expect(result.tenantMessages).toEqual([
      expect.objectContaining({
        buildingId: 'building-1',
        status: 'not_sent',
      }),
    ]);
  });
});
