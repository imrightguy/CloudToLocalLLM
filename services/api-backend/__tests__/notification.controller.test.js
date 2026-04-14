jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn().mockReturnThis(),
    from: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    offset: jest.fn().mockResolvedValue([]),
    insert: jest.fn().mockReturnValue({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'notif-1', userId: 'user-1' }]),
      }),
    }),
    update: jest.fn().mockReturnValue({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'notif-1', isRead: true }]),
        }),
      }),
    }),
  },
}));

jest.mock('../src/services/notification.service', () => ({
  sendEmail: jest.fn(),
}));

const notificationController = require('../src/controllers/notification.controller');
const { db } = require('../src/database/connection');

function setupDbQueries(queries) {
  let queryIdx = 0;

  db.where.mockImplementation(() => {
    if (queryIdx < queries.length && queries[queryIdx].via === 'where') {
      const result = queries[queryIdx].returns;
      queryIdx += 1;
      return Promise.resolve(result);
    }
    return db;
  });

  db.limit.mockImplementation(() => {
    if (queryIdx < queries.length && queries[queryIdx].via === 'limit') {
      const result = queries[queryIdx].returns;
      queryIdx += 1;
      return Promise.resolve(result);
    }
    return db;
  });

  db.offset.mockImplementation(() => {
    if (queryIdx < queries.length && queries[queryIdx].via === 'offset') {
      const result = queries[queryIdx].returns;
      queryIdx += 1;
      return Promise.resolve(result);
    }
    return Promise.resolve([]);
  });
}

describe('notification.controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    db.select.mockReturnThis();
    db.from.mockReturnThis();
    db.where.mockReturnThis();
    db.orderBy.mockReturnThis();
    db.limit.mockReturnThis();
    db.offset.mockResolvedValue([]);

    mockReq = {
      user: { id: 'user-1', email: 'admin@test.com', role: 'admin' },
      params: {},
      query: {},
      body: {},
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
  });

  describe('getPreferences', () => {
    it('returns existing preferences', async () => {
      const prefs = { id: 'pref-1', userId: 'user-1', emailNotifications: true, weeklyDigest: false };
      setupDbQueries([{ via: 'limit', returns: [prefs] }]);

      await notificationController.getPreferences(mockReq, mockRes);

      expect(mockRes.json).toHaveBeenCalledWith({ success: true, data: prefs });
    });

    it('creates default preferences when none exist', async () => {
      setupDbQueries([{ via: 'limit', returns: [] }]);

      await notificationController.getPreferences(mockReq, mockRes);

      expect(db.insert).toHaveBeenCalled();
      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true }),
      );
    });

    it('returns 500 on error', async () => {
      db.limit.mockRejectedValueOnce(new Error('DB down'));

      await notificationController.getPreferences(mockReq, mockRes);

      expect(mockRes.status).toHaveBeenCalledWith(500);
    });
  });

  describe('updatePreferences', () => {
    it('updates existing preferences', async () => {
      const existing = { id: 'pref-1', userId: 'user-1' };
      setupDbQueries([{ via: 'limit', returns: [existing] }]);

      mockReq.body = { emailNotifications: false, weeklyDigest: true };

      await notificationController.updatePreferences(mockReq, mockRes);

      expect(db.update).toHaveBeenCalled();
      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true }),
      );
    });

    it('creates preferences if none exist', async () => {
      setupDbQueries([{ via: 'limit', returns: [] }]);

      mockReq.body = { emailNotifications: false };

      await notificationController.updatePreferences(mockReq, mockRes);

      expect(db.insert).toHaveBeenCalled();
    });

    it('returns 400 when no valid fields provided', async () => {
      mockReq.body = { invalidField: true };

      await notificationController.updatePreferences(mockReq, mockRes);

      expect(mockRes.status).toHaveBeenCalledWith(400);
    });

    it('returns 500 on error', async () => {
      db.limit.mockRejectedValueOnce(new Error('DB down'));

      mockReq.body = { emailNotifications: true };

      await notificationController.updatePreferences(mockReq, mockRes);

      expect(mockRes.status).toHaveBeenCalledWith(500);
    });
  });

  describe('getNotifications', () => {
    it('returns paginated notifications', async () => {
      const notifications = [
        { id: 'n1', userId: 'user-1', type: 'new_lead', title: 'Test', isRead: false },
        { id: 'n2', userId: 'user-1', type: 'lease_signed', title: 'Test2', isRead: true },
      ];

      setupDbQueries([
        { via: 'where', returns: [{ count: 2 }] },
        { via: 'offset', returns: notifications },
      ]);

      await notificationController.getNotifications(mockReq, mockRes);

      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          metadata: expect.objectContaining({ total: 2, page: 1 }),
        }),
      );
    });

    it('filters by unreadOnly', async () => {
      mockReq.query = { unreadOnly: 'true' };

      setupDbQueries([
        { via: 'where', returns: [{ count: 1 }] },
        { via: 'offset', returns: [{ id: 'n1', isRead: false }] },
      ]);

      await notificationController.getNotifications(mockReq, mockRes);

      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true }),
      );
    });

    it('filters by type', async () => {
      mockReq.query = { type: 'new_lead' };

      setupDbQueries([
        { via: 'where', returns: [{ count: 1 }] },
        { via: 'offset', returns: [{ id: 'n1', type: 'new_lead' }] },
      ]);

      await notificationController.getNotifications(mockReq, mockRes);

      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true }),
      );
    });

    it('returns 500 on error', async () => {
      db.where.mockRejectedValueOnce(new Error('DB down'));

      await notificationController.getNotifications(mockReq, mockRes);

      expect(mockRes.status).toHaveBeenCalledWith(500);
    });
  });

  describe('markAsRead', () => {
    it('marks notification as read', async () => {
      const notif = { id: 'n1', userId: 'user-1', isRead: false };
      setupDbQueries([{ via: 'limit', returns: [notif] }]);

      mockReq.params = { id: 'n1' };

      await notificationController.markAsRead(mockReq, mockRes);

      expect(db.update).toHaveBeenCalled();
      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true }),
      );
    });

    it('returns 404 when notification not found', async () => {
      setupDbQueries([{ via: 'limit', returns: [] }]);

      mockReq.params = { id: 'n1' };

      await notificationController.markAsRead(mockReq, mockRes);

      expect(mockRes.status).toHaveBeenCalledWith(404);
    });
  });

  describe('markAllAsRead', () => {
    it('marks all unread notifications as read', async () => {
      await notificationController.markAllAsRead(mockReq, mockRes);

      expect(db.update).toHaveBeenCalled();
      expect(mockRes.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: { updatedCount: 1 },
        }),
      );
    });
  });

  describe('getUnreadCount', () => {
    it('returns unread notification count', async () => {
      setupDbQueries([{ via: 'where', returns: [{ count: 5 }] }]);

      await notificationController.getUnreadCount(mockReq, mockRes);

      expect(mockRes.json).toHaveBeenCalledWith({
        success: true,
        data: { count: 5 },
      });
    });

    it('returns 500 on error', async () => {
      db.where.mockRejectedValueOnce(new Error('DB down'));

      await notificationController.getUnreadCount(mockReq, mockRes);

      expect(mockRes.status).toHaveBeenCalledWith(500);
    });
  });

  describe('createNotification', () => {
    it('creates an in-app notification', async () => {
      const result = await notificationController.createNotification(
        'user-1', 'new_lead', 'Nouveau Lead', 'Jean Dupont est intéressé', { leadId: 'lead-1' },
      );

      expect(result).toEqual({ id: 'notif-1', userId: 'user-1' });
    });

    it('returns null on error', async () => {
      db.insert.mockReturnValueOnce({
        values: jest.fn().mockReturnValue({
          returning: jest.fn().mockRejectedValue(new Error('DB down')),
        }),
      });

      const result = await notificationController.createNotification('user-1', 'test', 'Test', 'Msg');

      expect(result).toBeNull();
    });
  });

  describe('notifyAllAdmins', () => {
    it('creates notifications for all admins', async () => {
      setupDbQueries([{ via: 'where', returns: [{ id: 'admin-1' }, { id: 'admin-2' }] }]);

      const results = await notificationController.notifyAllAdmins('system', 'System', 'Test');

      expect(results).toHaveLength(2);
    });
  });
});
