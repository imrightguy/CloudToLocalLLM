const {
  eq, and, desc, count,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const {
  usersTable, notificationPreferencesTable, notificationsTable,
} = require('../database/schema');
const { child } = require('../utils/logger');

const log = child({ controller: 'notification' });

exports.getPreferences = async (req, res) => {
  try {
    const userId = req.user.id;

    let prefs = await db
      .select()
      .from(notificationPreferencesTable)
      .where(eq(notificationPreferencesTable.userId, userId))
      .limit(1);

    if (!prefs.length) {
      const [created] = await db
        .insert(notificationPreferencesTable)
        .values({ userId })
        .returning();
      return res.json({ success: true, data: created });
    }

    return res.json({ success: true, data: prefs[0] });
  } catch (error) {
    log.error('Error getting preferences', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'PREFERENCES_FETCH_FAILED' },
    });
  }
};

exports.updatePreferences = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      emailNotifications,
      smsNotifications,
      weeklyDigest,
      quietHoursEnabled,
      quietHoursStart,
      quietHoursEnd,
    } = req.body;

    const allowedFields = {};
    if (typeof emailNotifications === 'boolean') allowedFields.emailNotifications = emailNotifications;
    if (typeof smsNotifications === 'boolean') allowedFields.smsNotifications = smsNotifications;
    if (typeof weeklyDigest === 'boolean') allowedFields.weeklyDigest = weeklyDigest;
    if (typeof quietHoursEnabled === 'boolean') allowedFields.quietHoursEnabled = quietHoursEnabled;
    if (quietHoursStart !== undefined) allowedFields.quietHoursStart = quietHoursStart;
    if (quietHoursEnd !== undefined) allowedFields.quietHoursEnd = quietHoursEnd;

    if (Object.keys(allowedFields).length === 0) {
      return res.status(400).json({
        success: false,
        error: { message: 'No valid fields to update', code: 'VALIDATION_ERROR' },
      });
    }

    const [existing] = await db
      .select()
      .from(notificationPreferencesTable)
      .where(eq(notificationPreferencesTable.userId, userId))
      .limit(1);

    let result;
    if (!existing) {
      [result] = await db
        .insert(notificationPreferencesTable)
        .values({ userId, ...allowedFields })
        .returning();
    } else {
      [result] = await db
        .update(notificationPreferencesTable)
        .set({ ...allowedFields, updatedAt: new Date() })
        .where(eq(notificationPreferencesTable.userId, userId))
        .returning();
    }

    return res.json({ success: true, data: result, message: 'Preferences updated' });
  } catch (error) {
    log.error('Error updating preferences', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'PREFERENCES_UPDATE_FAILED' },
    });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      page = 1,
      limit = 20,
      unreadOnly = false,
      type,
    } = req.query;

    const validPage = Math.max(1, parseInt(page));
    const validLimit = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (validPage - 1) * validLimit;

    const conditions = [eq(notificationsTable.userId, userId)];

    if (unreadOnly === 'true' || unreadOnly === true) {
      conditions.push(eq(notificationsTable.isRead, false));
    }

    if (type) {
      conditions.push(eq(notificationsTable.type, type));
    }

    const whereClause = conditions.length > 1 ? and(...conditions) : conditions[0];

    const [totalCount] = await db
      .select({ count: count() })
      .from(notificationsTable)
      .where(whereClause);

    const items = await db
      .select()
      .from(notificationsTable)
      .where(whereClause)
      .orderBy(desc(notificationsTable.createdAt))
      .limit(validLimit)
      .offset(offset);

    const totalPages = Math.ceil(totalCount.count / validLimit);

    return res.json({
      success: true,
      data: items,
      metadata: {
        total: totalCount.count,
        page: validPage,
        limit: validLimit,
        totalPages,
        hasNext: validPage < totalPages,
        hasPrev: validPage > 1,
      },
    });
  } catch (error) {
    log.error('Error getting notifications', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'NOTIFICATIONS_FETCH_FAILED' },
    });
  }
};

exports.markAsRead = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const [notification] = await db
      .select()
      .from(notificationsTable)
      .where(and(
        eq(notificationsTable.id, id),
        eq(notificationsTable.userId, userId),
      ))
      .limit(1);

    if (!notification) {
      return res.status(404).json({
        success: false,
        error: { message: 'Notification not found', code: 'NOT_FOUND' },
      });
    }

    const [updated] = await db
      .update(notificationsTable)
      .set({ isRead: true })
      .where(and(
        eq(notificationsTable.id, id),
        eq(notificationsTable.userId, userId),
      ))
      .returning();

    return res.json({ success: true, data: updated, message: 'Notification marked as read' });
  } catch (error) {
    log.error('Error marking notification as read', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'NOTIFICATION_UPDATE_FAILED' },
    });
  }
};

exports.markAllAsRead = async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await db
      .update(notificationsTable)
      .set({ isRead: true })
      .where(and(
        eq(notificationsTable.userId, userId),
        eq(notificationsTable.isRead, false),
      ))
      .returning();

    return res.json({
      success: true,
      data: { updatedCount: result.length },
      message: `Marked ${result.length} notification(s) as read`,
    });
  } catch (error) {
    log.error('Error marking all notifications as read', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'NOTIFICATIONS_UPDATE_FAILED' },
    });
  }
};

exports.createNotification = async (userId, type, title, message, data = {}) => {
  try {
    const [notification] = await db
      .insert(notificationsTable)
      .values({ userId, type, title, message, data })
      .returning();

    return notification;
  } catch (error) {
    log.error('Error creating in-app notification', { error: error.message });
    return null;
  }
};

exports.notifyAllAdmins = async (type, title, message, data = {}) => {
  try {
    const admins = await db
      .select({ id: usersTable.id })
      .from(usersTable)
      .where(eq(usersTable.role, 'admin'));

    const results = [];
    for (const admin of admins) {
      const notification = await exports.createNotification(
        admin.id, type, title, message, data,
      );
      if (notification) results.push(notification);
    }

    return results;
  } catch (error) {
    log.error('Error notifying all admins', { error: error.message });
    return [];
  }
};

exports.getUnreadCount = async (req, res) => {
  try {
    const userId = req.user.id;

    const [result] = await db
      .select({ count: count() })
      .from(notificationsTable)
      .where(and(
        eq(notificationsTable.userId, userId),
        eq(notificationsTable.isRead, false),
      ));

    return res.json({ success: true, data: { count: result.count } });
  } catch (error) {
    log.error('Error getting unread count', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'NOTIFICATIONS_FETCH_FAILED' },
    });
  }
};
