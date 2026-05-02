const { calculateFirstResponseMetrics } = require('../../src/services/communication-thread.service');

describe('calculateFirstResponseMetrics', () => {
  it('measures first-response delay from the first inbound message to the first outbound reply', () => {
    const metrics = calculateFirstResponseMetrics([
      { direction: 'outbound', createdAt: '2026-05-01T08:00:00.000Z' },
      { direction: 'inbound', createdAt: '2026-05-01T09:15:00.000Z' },
      { direction: 'outbound', createdAt: '2026-05-01T09:27:00.000Z' },
      { direction: 'outbound', createdAt: '2026-05-01T09:35:00.000Z' },
    ]);

    expect(metrics.firstSeenAt).toBe('2026-05-01T09:15:00.000Z');
    expect(metrics.firstResponseAt).toBe('2026-05-01T09:27:00.000Z');
    expect(metrics.firstResponseDelayMinutes).toBe(12);
  });

  it('returns null response metrics when the thread has no outbound reply', () => {
    const metrics = calculateFirstResponseMetrics([
      { direction: 'inbound', createdAt: '2026-05-01T09:15:00.000Z' },
      { direction: 'inbound', createdAt: '2026-05-01T09:40:00.000Z' },
    ]);

    expect(metrics).toEqual({
      firstSeenAt: '2026-05-01T09:15:00.000Z',
      firstResponseAt: null,
      firstResponseDelayMinutes: null,
    });
  });
});
