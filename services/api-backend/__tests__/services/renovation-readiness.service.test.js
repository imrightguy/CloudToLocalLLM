const { deriveReadinessProjection } = require('../../src/services/renovation-readiness.service');

describe('deriveReadinessProjection', () => {
  it('counts blocked tasks and unresolved blocker intake records', () => {
    const projection = deriveReadinessProjection({
      renovationRecord: {
        id: 'reno-1',
        status: 'blocked',
        readinessState: 'blocked',
      },
      tasks: [
        { title: 'Paint bedroom', status: 'blocked' },
        { title: 'Install fixtures', status: 'done' },
      ],
      intakes: [
        { messageKind: 'missing_material', status: 'linked', summary: 'Need more anchors' },
        { messageKind: 'update', status: 'new', summary: 'Progress note' },
      ],
      existingReadiness: {
        readyAt: null,
        handedOffAt: null,
        leasedAt: null,
      },
      now: new Date('2026-05-01T12:00:00.000Z'),
    });

    expect(projection).toEqual(expect.objectContaining({
      currentRenovationRecordId: 'reno-1',
      opsStatus: 'blocked',
      leasingStatus: 'not_ready',
      blockingCount: 2,
    }));
    expect(projection.blockingSummary).toContain('Paint bedroom');
    expect(projection.blockingSummary).toContain('Need more anchors');
  });

  it('preserves the original ready timestamp once a unit is ready for leasing', () => {
    const readyAt = new Date('2026-05-01T10:00:00.000Z');
    const projection = deriveReadinessProjection({
      renovationRecord: {
        id: 'reno-1',
        status: 'ready_for_leasing',
        readinessState: 'ready_for_leasing',
      },
      tasks: [],
      intakes: [],
      existingReadiness: {
        readyAt,
        handedOffAt: null,
        leasedAt: null,
      },
      now: new Date('2026-05-01T12:00:00.000Z'),
    });

    expect(projection.opsStatus).toBe('ready_for_leasing');
    expect(projection.leasingStatus).toBe('ready');
    expect(projection.readyAt).toBe(readyAt);
    expect(projection.blockingCount).toBe(0);
  });
});
