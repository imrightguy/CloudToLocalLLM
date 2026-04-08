// ─── Notification Service — Phase 4 ───
const nodemailer = require('nodemailer');
const { db } = require('../database/connection');
const {
  usersTable, leadsTable, visitsTable, buildingsTable, employeesTable,
} = require('../database/schema');
const { eq } = require('drizzle-orm');
const analyticsService = require('./analytics.service');

let transporter = null;

// ─── Init Mailer ───

function initMailer() {
  try {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT, 10) || 587,
      secure: parseInt(process.env.SMTP_PORT, 10) === 465,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
    console.log('[notification.service] Mailer initialized');
    return transporter;
  } catch (error) {
    console.error('[notification.service] initMailer error:', error);
    throw error;
  }
}

// ─── Send Email ───

async function sendEmail(to, subject, html) {
  try {
    if (!transporter) {
      initMailer();
    }

    if (!process.env.SMTP_HOST) {
      console.warn('[notification.service] SMTP not configured, skipping email send');
      return { success: false, reason: 'SMTP_NOT_CONFIGURED' };
    }

    const info = await transporter.sendMail({
      from: process.env.SMTP_FROM || process.env.SMTP_USER || 'noreply@immogestion.ca',
      to,
      subject,
      html,
    });

    console.log(`[notification.service] Email sent to ${to}: ${info.messageId}`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error('[notification.service] sendEmail error:', error);
    return { success: false, error: error.message };
  }
}

// ─── Send Weekly Summary ───

async function sendWeeklySummary() {
  try {
    // Fetch admin users
    const admins = await db
      .select()
      .from(usersTable)
      .where(eq(usersTable.role, 'admin'));

    if (!admins.length) {
      console.warn('[notification.service] No admin users found for weekly summary');
      return;
    }

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
          .footer { padding: 20px; text-align: center; color: #999; font-size: 12px; border-top: 1px solid #eee; }
          .footer a { color: #1a73e8; text-decoration: none; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>📊 Résumé Hebdomadaire ImmoGestion</h1>
            <p>Semaine du ${new Date(summary.periodStart).toLocaleDateString('fr-CA', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</p>
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
      if (!admin.email) continue;
      const result = await sendEmail(
        admin.email,
        `📊 Résumé Hebdomadaire — ${new Date(summary.periodStart).toLocaleDateString('fr-CA')}`,
        html,
      );
      results.push({ email: admin.email, ...result });
    }

    return results;
  } catch (error) {
    console.error('[notification.service] sendWeeklySummary error:', error);
    throw error;
  }
}

// ─── Send Hot Lead Notification ───

async function sendHotLeadNotification(leadId) {
  try {
    const [lead] = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.id, leadId))
      .limit(1);

    if (!lead) {
      console.warn(`[notification.service] Lead ${leadId} not found`);
      return { success: false, reason: 'LEAD_NOT_FOUND' };
    }

    // Fetch admin users to notify
    const admins = await db
      .select()
      .from(usersTable)
      .where(eq(usersTable.role, 'admin'));

    if (!admins.length) {
      console.warn('[notification.service] No admin users found');
      return { success: false, reason: 'NO_ADMINS' };
    }

    // Fetch building name if available
    let buildingName = 'Non assigné';
    if (lead.buildingId) {
      const [building] = await db
        .select({ name: buildingsTable.name })
        .from(buildingsTable)
        .where(eq(buildingsTable.id, lead.buildingId))
        .limit(1);
      if (building) buildingName = building.name;
    }

    const sourceLabels = {
      facebook: 'Facebook',
      website: 'Site Web',
      referral: 'Référence',
      other: 'Autre',
    };

    const html = `
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: Arial, sans-serif; background: #f4f6f9; margin: 0; padding: 20px; }
          .container { max-width: 500px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
          .header { background: linear-gradient(135deg, #ff6f00, #e65100); color: #ffffff; padding: 24px; text-align: center; }
          .header h1 { margin: 0; font-size: 22px; }
          .header p { margin: 6px 0 0; opacity: 0.9; font-size: 13px; }
          .body-content { padding: 24px; }
          .detail-row { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #f0f0f0; }
          .detail-label { color: #6c757d; font-size: 14px; }
          .detail-value { font-weight: 600; font-size: 14px; color: #1a1a2e; }
          .cta { display: block; width: 100%; padding: 14px; background: #ff6f00; color: #fff; text-align: center; text-decoration: none; border-radius: 8px; font-weight: 600; margin-top: 20px; }
          .footer { padding: 16px; text-align: center; color: #999; font-size: 12px; border-top: 1px solid #eee; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🔥 Lead Chaud Détecté!</h1>
            <p>Un prospect est intéressé — agissez rapidement</p>
          </div>
          <div class="body-content">
            <div class="detail-row">
              <span class="detail-label">Nom</span>
              <span class="detail-value">${lead.fullName}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Téléphone</span>
              <span class="detail-value">${lead.phone || 'N/A'}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Courriel</span>
              <span class="detail-value">${lead.email || 'N/A'}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Source</span>
              <span class="detail-value">${sourceLabels[lead.source] || lead.source}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Immeuble</span>
              <span class="detail-value">${buildingName}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Langue</span>
              <span class="detail-value">${lead.language === 'en' ? 'Anglais' : 'Français'}</span>
            </div>
            <a href="${process.env.APP_URL || 'https://app.immogestion.ca'}/leads" class="cta">Voir le Lead →</a>
          </div>
          <div class="footer">
            <p>ImmoGestion — Moteur d'automatisation de location au Québec</p>
          </div>
        </div>
      </body>
      </html>
    `;

    const results = [];
    for (const admin of admins) {
      if (!admin.email) continue;
      const result = await sendEmail(
        admin.email,
        `🔥 Lead Chaud — ${lead.fullName}`,
        html,
      );
      results.push({ email: admin.email, ...result });
    }

    return results;
  } catch (error) {
    console.error('[notification.service] sendHotLeadNotification error:', error);
    throw error;
  }
}

// ─── Send No-Show Alert ───

async function sendNoShowAlert(visitId) {
  try {
    const [visit] = await db
      .select()
      .from(visitsTable)
      .where(eq(visitsTable.id, visitId))
      .limit(1);

    if (!visit) {
      console.warn(`[notification.service] Visit ${visitId} not found`);
      return { success: false, reason: 'VISIT_NOT_FOUND' };
    }

    // Fetch lead info
    const [lead] = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.id, visit.leadId))
      .limit(1);

    // Fetch employee info
    const [employee] = await db
      .select()
      .from(employeesTable)
      .where(eq(employeesTable.id, visit.employeeId))
      .limit(1);

    // Fetch building info via unit
    const { unitsTable } = require('../database/schema');
    let buildingName = 'Non assigné';
    if (visit.unitId) {
      const [unit] = await db
        .select({ buildingId: unitsTable.buildingId })
        .from(unitsTable)
        .where(eq(unitsTable.id, visit.unitId))
        .limit(1);
      if (unit && unit.buildingId) {
        const [building] = await db
          .select({ name: buildingsTable.name })
          .from(buildingsTable)
          .where(eq(buildingsTable.id, unit.buildingId))
          .limit(1);
        if (building) buildingName = building.name;
      }
    }

    const visitDate = new Date(visit.dateTime).toLocaleString('fr-CA', {
      weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });

    const html = `
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: Arial, sans-serif; background: #f4f6f9; margin: 0; padding: 20px; }
          .container { max-width: 500px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
          .header { background: linear-gradient(135deg, #e53935, #b71c1c); color: #ffffff; padding: 24px; text-align: center; }
          .header h1 { margin: 0; font-size: 22px; }
          .header p { margin: 6px 0 0; opacity: 0.9; font-size: 13px; }
          .body-content { padding: 24px; }
          .detail-row { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #f0f0f0; }
          .detail-label { color: #6c757d; font-size: 14px; }
          .detail-value { font-weight: 600; font-size: 14px; color: #1a1a2e; }
          .alert-box { background: #fff3e0; border-left: 4px solid #e53935; padding: 14px; margin: 16px 0; border-radius: 4px; font-size: 14px; color: #bf360c; }
          .footer { padding: 16px; text-align: center; color: #999; font-size: 12px; border-top: 1px solid #eee; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>⚠️ Absence Non-Présentée</h1>
            <p>Un locataire potentiel ne s'est pas présenté</p>
          </div>
          <div class="body-content">
            <div class="alert-box">
              Le locataire ne s'est pas présenté à la visite prévue. Une relance est recommandée.
            </div>
            <div class="detail-row">
              <span class="detail-label">Lead</span>
              <span class="detail-value">${lead ? lead.fullName : 'N/A'}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Téléphone</span>
              <span class="detail-value">${lead && lead.phone ? lead.phone : 'N/A'}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Date de visite</span>
              <span class="detail-value">${visitDate}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Employé</span>
              <span class="detail-value">${employee ? `${employee.firstName} ${employee.lastName}` : 'N/A'}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Immeuble</span>
              <span class="detail-value">${buildingName}</span>
            </div>
          </div>
          <div class="footer">
            <p>ImmoGestion — Moteur d'automatisation de location au Québec</p>
          </div>
        </div>
      </body>
      </html>
    `;

    // Fetch admin users
    const admins = await db
      .select()
      .from(usersTable)
      .where(eq(usersTable.role, 'admin'));

    const results = [];
    for (const admin of admins) {
      if (!admin.email) continue;
      const result = await sendEmail(
        admin.email,
        `⚠️ Absence Non-Présentée — ${lead ? lead.fullName : 'Visite'}`,
        html,
      );
      results.push({ email: admin.email, ...result });
    }

    return results;
  } catch (error) {
    console.error('[notification.service] sendNoShowAlert error:', error);
    throw error;
  }
}

module.exports = {
  initMailer,
  sendEmail,
  sendWeeklySummary,
  sendHotLeadNotification,
  sendNoShowAlert,
};
