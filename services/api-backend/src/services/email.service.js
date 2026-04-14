const notificationService = require('./notification.service');
const { eq } = require('drizzle-orm');
const { db } = require('../database/connection');
const { notificationPreferencesTable, usersTable } = require('../database/schema');
const logger = require('../utils/logger');

async function getUserPreferences(userId) {
  const prefs = await db
    .select()
    .from(notificationPreferencesTable)
    .where(eq(notificationPreferencesTable.userId, userId))
    .limit(1);

  return prefs.length > 0 ? prefs[0] : null;
}

async function shouldSendEmail(userId) {
  if (!process.env.SMTP_HOST) return false;

  const prefs = await getUserPreferences(userId);
  if (!prefs) return true;

  if (!prefs.emailNotifications) return false;

  if (prefs.quietHoursEnabled) {
    const now = new Date();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();
    const [startH, startM] = (prefs.quietHoursStart || '22:00').split(':').map(Number);
    const [endH, endM] = (prefs.quietHoursEnd || '08:00').split(':').map(Number);
    const startMinutes = startH * 60 + startM;
    const endMinutes = endH * 60 + endM;

    if (startMinutes <= endMinutes) {
      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) return false;
    } else {
      if (currentMinutes >= startMinutes || currentMinutes < endMinutes) return false;
    }
  }

  return true;
}

async function sendEmailToUser(userId, subject, html) {
  const canSend = await shouldSendEmail(userId);
  if (!canSend) {
    logger.info(`[email.service] Skipping email to user ${userId} (preferences or quiet hours)`);
    return { success: false, reason: 'PREFERENCES_BLOCKED' };
  }

  const [user] = await db
    .select()
    .from(usersTable)
    .where(eq(usersTable.id, userId))
    .limit(1);

  if (!user || !user.email) {
    return { success: false, reason: 'NO_EMAIL' };
  }

  return notificationService.sendEmail(user.email, subject, html);
}

async function sendWeeklyDigestToAll() {
  const admins = await db
    .select()
    .from(usersTable)
    .where(eq(usersTable.role, 'admin'));

  if (!admins.length) {
    logger.warn('[email.service] No admin users found for weekly digest');
    return [];
  }

  const analyticsService = require('./analytics.service');
  const summary = await analyticsService.getWeeklySummary();

  const html = `
    <!DOCTYPE html>
    <html lang="fr">
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: Arial, sans-serif; background: #f4f6f9; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
        .header { background: linear-gradient(135deg, #1a73e8, #0d47a1); color: #ffffff; padding: 30px; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .header p { margin: 8px 0 0; opacity: 0.9; font-size: 14px; }
        .stats { display: flex; flex-wrap: wrap; padding: 20px; gap: 16px; }
        .stat-card { flex: 1 1 calc(50% - 16px); background: #f8f9fa; border-radius: 10px; padding: 20px; text-align: center; border-left: 4px solid #1a73e8; }
        .stat-card.warning { border-left-color: #f9a825; }
        .stat-card.success { border-left-color: #43a047; }
        .stat-card.danger { border-left-color: #e53935; }
        .stat-value { font-size: 32px; font-weight: 700; color: #1a1a2e; margin: 0; }
        .stat-label { font-size: 13px; color: #6c757d; margin: 6px 0 0; text-transform: uppercase; letter-spacing: 0.5px; }
        .section { padding: 20px; }
        .section h2 { font-size: 18px; color: #1a1a2e; margin: 0 0 12px; }
        .lease-item { background: #f8f9fa; padding: 12px; border-radius: 8px; margin-bottom: 8px; display: flex; justify-content: space-between; align-items: center; }
        .lease-tenant { font-weight: 600; }
        .lease-building { color: #6c757d; font-size: 13px; }
        .lease-status { background: #43a047; color: white; padding: 4px 10px; border-radius: 12px; font-size: 12px; }
        .footer { padding: 20px; text-align: center; color: #999; font-size: 12px; border-top: 1px solid #eee; }
        .footer a { color: #1a73e8; text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Résumé Hebdomadaire ImmoGestion</h1>
          <p>Semaine du ${new Date(summary.periodStart).toLocaleDateString('fr-CA', {
            weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
          })}</p>
        </div>
        <div class="stats">
          <div class="stat-card">
            <p class="stat-value">${summary.newLeads}</p>
            <p class="stat-label">Nouveaux Leads</p>
          </div>
          <div class="stat-card success">
            <p class="stat-value">${summary.visitsCompleted}</p>
            <p class="stat-label">Visites Complétées</p>
          </div>
          <div class="stat-card success">
            <p class="stat-value">${summary.conversions}</p>
            <p class="stat-label">Conversions</p>
          </div>
          <div class="stat-card warning">
            <p class="stat-value">${summary.hotLeadsCount}</p>
            <p class="stat-label">Leads Chauds</p>
          </div>
          <div class="stat-card danger">
            <p class="stat-value">${summary.noShows}</p>
            <p class="stat-label">Absences (No-Show)</p>
          </div>
        </div>
        <div class="footer">
          <p>ImmoGestion — Moteur d'automatisation de location au Québec</p>
          <p>Généré le ${new Date(summary.generatedAt).toLocaleString('fr-CA')}</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const results = [];
  for (const admin of admins) {
    const canSend = await shouldSendEmail(admin.id);
    if (!canSend) {
      results.push({ userId: admin.id, email: admin.email, success: false, reason: 'PREFERENCES_BLOCKED' });
      continue;
    }

    if (!admin.email) {
      results.push({ userId: admin.id, success: false, reason: 'NO_EMAIL' });
      continue;
    }

    const sendResult = await notificationService.sendEmail(
      admin.email,
      `Résumé Hebdomadaire — ${new Date(summary.periodStart).toLocaleDateString('fr-CA')}`,
      html,
    );
    results.push({ userId: admin.id, email: admin.email, ...sendResult });
  }

  return results;
}

module.exports = {
  getUserPreferences,
  shouldSendEmail,
  sendEmailToUser,
  sendWeeklyDigestToAll,
};
