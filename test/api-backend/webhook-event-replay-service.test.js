import { describe, it, expect, beforeEach } from '@jest/globals';
import WebhookEventReplayService from '../../services/api-backend/services/webhook-event-replay-service.js';

describe('WebhookEventReplayService', () => {
  let service;

  beforeEach(() => {
    service = new WebhookEventReplayService();
  });

  describe('constructor', () => {
    it('initializes with empty replays map', () => {
      expect(service.replays).toBeInstanceOf(Map);
      expect(service.replays.size).toBe(0);
    });
  });

  describe('replayEvent', () => {
    it('creates a replay entry and returns a replay ID', async () => {
      const replayId = await service.replayEvent('evt-123', 'wh-456');

      expect(replayId).toMatch(/^replay-\d+$/);
      expect(service.replays.size).toBe(1);
    });

    it('stores correct replay data', async () => {
      const before = Date.now();
      const replayId = await service.replayEvent('evt-abc', 'wh-def');
      const after = Date.now();

      const replay = service.replays.get(replayId);
      expect(replay).toEqual({
        eventId: 'evt-abc',
        webhookId: 'wh-def',
        status: 'pending',
        createdAt: expect.any(Date),
      });
      expect(replay.createdAt.getTime()).toBeGreaterThanOrEqual(before);
      expect(replay.createdAt.getTime()).toBeLessThanOrEqual(after);
    });

    it('allows multiple replays to be created with unique IDs', async () => {
      const id1 = await service.replayEvent('evt-1', 'wh-1');
      await new Promise((r) => setTimeout(r, 2));
      const id2 = await service.replayEvent('evt-2', 'wh-2');

      expect(id1).not.toBe(id2);
      expect(service.replays.size).toBe(2);
    });
  });

  describe('getReplayStatus', () => {
    it('returns null for unknown replay ID', () => {
      expect(service.getReplayStatus('nonexistent')).toBeNull();
    });

    it('returns replay data for valid replay ID', async () => {
      const replayId = await service.replayEvent('evt-x', 'wh-y');
      const status = service.getReplayStatus(replayId);

      expect(status).toBeDefined();
      expect(status.eventId).toBe('evt-x');
      expect(status.webhookId).toBe('wh-y');
      expect(status.status).toBe('pending');
    });

    it('returns independent copies for different replays', async () => {
      const id1 = await service.replayEvent('evt-a', 'wh-a');
      await new Promise((r) => setTimeout(r, 2));
      const id2 = await service.replayEvent('evt-b', 'wh-b');

      const status1 = service.getReplayStatus(id1);
      const status2 = service.getReplayStatus(id2);

      expect(status1.eventId).toBe('evt-a');
      expect(status2.eventId).toBe('evt-b');
    });
  });
});
