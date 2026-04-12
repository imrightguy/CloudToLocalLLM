const crypto = require('crypto');
const { eq, and } = require('drizzle-orm');
const logger = require('../utils/logger');
const { db } = require('../database/connection');
const {
  visitsTable, employeesTable, leadsTable, unitsTable, buildingsTable, smsLogsTable,
} = require('../database/schema');

function esc(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Generate a secure, URL-safe confirmation token.
 */
function generateConfirmationToken() {
  return crypto.randomBytes(32).toString('base64url');
}

/**
 * GET /confirm/:token
 * Public endpoint — tenant clicks the link from their SMS.
 * Returns a simple HTML page with confirm/decline buttons (or JSON if ?format=json).
 */
const getConfirmationPage = async (req, res) => {
  try {
    const { token } = req.params;
    const { format } = req.query;

    // Look up visit by confirmation token
    const [visit] = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.confirmationToken, token),
        eq(visitsTable.isActive, true),
      ))
      .limit(1);

    if (!visit) {
      if (format === 'json') {
        return res.status(404).json({
          success: false,
          error: { message: 'Invalid or expired confirmation link', code: 'INVALID_TOKEN' },
        });
      }
      return res.status(404).send(`
        <!DOCTYPE html>
        <html lang="fr">
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Lien invalide</title>
        <style>body{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#f5f5f5;color:#333}p{text-align:center;padding:2rem}</style></head>
        <body><p>❌ Ce lien de confirmation est invalide ou a expiré.</p></body>
        </html>
      `);
    }

    // Already confirmed/declined/cancelled/completed
    if (visit.tenantConfirmed || visit.status === 'cancelled' || visit.status === 'completed') {
      const alreadyMsg = visit.tenantConfirmed
        ? 'Vous avez déjà confirmé votre visite.'
        : 'Cette visite a été annulée ou terminée.';
      if (format === 'json') {
        return res.json({
          success: true,
          data: { visitId: visit.id, tenantConfirmed: visit.tenantConfirmed, status: visit.status },
          message: alreadyMsg,
        });
      }
      return res.send(`
        <!DOCTYPE html>
        <html lang="fr">
        <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Confirmation</title>
        <style>body{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#f5f5f5;color:#333}p{text-align:center;padding:2rem}</style></head>
        <body><p>✅ ${alreadyMsg}</p></body>
        </html>
      `);
    }

    // Get visit context for display
    const rows = await db
      .select({
        visit: visitsTable,
        lead: leadsTable,
        unit: unitsTable,
        building: buildingsTable,
        employee: employeesTable,
      })
      .from(visitsTable)
      .leftJoin(leadsTable, eq(visitsTable.leadId, leadsTable.id))
      .leftJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
      .leftJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
      .leftJoin(employeesTable, eq(visitsTable.employeeId, employeesTable.id))
      .where(eq(visitsTable.id, visit.id))
      .limit(1);

    const ctx = rows[0] || {};
    const {
      lead, unit, building, employee,
    } = ctx;
    const dateTime = new Date(visit.dateTime).toLocaleDateString('fr-CA', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
    const lang = (lead?.language === 'en') ? 'en' : 'fr';

    if (format === 'json') {
      return res.json({
        success: true,
        data: {
          visitId: visit.id,
          dateTime,
          building: building?.name,
          unit: unit?.label,
          employee: employee ? `${employee.firstName} ${employee.lastName}` : null,
          tenantConfirmed: visit.tenantConfirmed,
          status: visit.status,
        },
      });
    }

    // HTML confirmation page
    const bName = esc(building?.name || 'TBD');
    const uLabel = esc(unit?.label || '');
    const eName = employee ? esc(`${employee.firstName} ${employee.lastName}`) : '';
    const ui = lang === 'en' ? {
      title: 'Confirm Your Visit',
      heading: 'Confirm Your Visit',
      details: `${dateTime} at ${bName} ${uLabel}`,
      withAgent: eName ? `with ${eName}` : '',
      confirmBtn: '✅ Confirm',
      declineBtn: '❌ Decline',
      alreadyMsg: 'You have already responded.',
    } : {
      title: 'Confirmez votre visite',
      heading: 'Confirmez votre visite',
      details: `${dateTime} à ${bName} ${uLabel}`,
      withAgent: eName ? `avec ${eName}` : '',
      confirmBtn: '✅ Confirmer',
      declineBtn: '❌ Décliner',
      alreadyMsg: 'Vous avez déjà répondu.',
    };

    const baseUrl = process.env.PUBLIC_URL || process.env.PAPERCLIP_PUBLIC_URL || '';
    const confirmUrl = `${baseUrl}/api/confirm/${token}`;
    const declineUrl = `${baseUrl}/api/confirm/${token}?action=decline`;

    res.send(`
      <!DOCTYPE html>
      <html lang="${lang}">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>${ui.title}</title>
        <style>
          body{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#f5f5f5;color:#333}
          .card{background:#fff;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,.1);padding:2rem;max-width:400px;width:90%;text-align:center}
          h1{font-size:1.3rem;margin-bottom:.5rem}
          .details{color:#555;margin-bottom:1.5rem;font-size:.95rem}
          .btn{display:block;width:100%;padding:.8rem;margin:.5rem 0;border:none;border-radius:8px;font-size:1rem;cursor:pointer;text-decoration:none}
          .btn-confirm{background:#22c55e;color:#fff}
          .btn-decline{background:#ef4444;color:#fff}
          .btn:active{opacity:.8}
        </style>
      </head>
      <body>
        <div class="card">
          <h1>${ui.heading}</h1>
          <p class="details">${ui.details}<br>${ui.withAgent}</p>
          <form method="post" action="${confirmUrl}">
            <button type="submit" class="btn btn-confirm">${ui.confirmBtn}</button>
          </form>
          <form method="post" action="${declineUrl}">
            <button type="submit" class="btn btn-decline">${ui.declineBtn}</button>
          </form>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    logger.error('Error rendering confirmation page:', error);
    res.status(500).send('Internal error');
  }
};

/**
 * POST /confirm/:token
 * Public endpoint — tenant submits confirm or decline from the web page.
 * Body: { action: 'confirm' | 'decline' } or query param ?action=confirm|decline
 */
const submitConfirmation = async (req, res) => {
  try {
    const { token } = req.params;
    const action = req.body?.action || req.query?.action || 'confirm';

    if (!['confirm', 'decline'].includes(action)) {
      return res.status(400).json({
        success: false,
        error: { message: 'Action must be confirm or decline', code: 'INVALID_ACTION' },
      });
    }

    // Look up visit by confirmation token
    const [visit] = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.confirmationToken, token),
        eq(visitsTable.isActive, true),
      ))
      .limit(1);

    if (!visit) {
      if (req.accepts('html')) {
        return res.status(404).send(`
          <!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Erreur</title></head>
          <body style="font-family:system-ui;text-align:center;padding:2rem"><p>❌ Lien invalide ou expiré.</p></body></html>
        `);
      }
      return res.status(404).json({
        success: false,
        error: { message: 'Invalid or expired confirmation link', code: 'INVALID_TOKEN' },
      });
    }

    // Already handled
    if (visit.tenantConfirmed) {
      const msg = 'You already confirmed this visit.';
      if (req.accepts('html')) {
        return res.send(`
          <!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Déjà confirmé</title></head>
          <body style="font-family:system-ui;text-align:center;padding:2rem"><p>✅ Vous avez déjà confirmé cette visite.</p></body></html>
        `);
      }
      return res.json({ success: true, data: { visitId: visit.id, tenantConfirmed: true }, message: msg });
    }

    const tenantConfirmed = action === 'confirm';

    // Update visit
    const [updated] = await db
      .update(visitsTable)
      .set({
        tenantConfirmed,
        updatedAt: new Date(),
      })
      .where(eq(visitsTable.id, visit.id))
      .returning();

    // Get lead info for logging
    const [lead] = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.id, visit.leadId))
      .limit(1);

    // Log the web confirmation as an SMS-equivalent entry for audit trail
    if (lead?.phone) {
      await db.insert(smsLogsTable).values({
        visitId: visit.id,
        employeeId: visit.employeeId,
        leadId: visit.leadId,
        phoneNumber: lead.phone,
        direction: 'inbound',
        messageBody: `[web] tenant_${action}`,
        status: 'received',
      });
    }

    logger.info(`🔗 Tenant web confirmation: token=${token.substring(0, 8)}... action=${action}, visit=${visit.id}`);

    // Return HTML or JSON based on Accept header
    if (req.accepts('html')) {
      const lang = (lead?.language === 'en') ? 'en' : 'fr';
      if (tenantConfirmed) {
        const msg = lang === 'en'
          ? 'Your visit has been confirmed! See you soon.'
          : 'Votre visite est confirmée ! À bientôt.';
        return res.send(`
          <!DOCTYPE html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Confirmé</title></head>
          <body style="font-family:system-ui;text-align:center;padding:2rem"><p>✅ ${msg}</p></body></html>
        `);
      }
      const msg = lang === 'en'
        ? 'You declined the visit. Thank you for letting us know.'
        : 'Vous avez décliné la visite. Merci de nous avoir informés.';
      return res.send(`
        <!DOCTYPE html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Décliné</title></head>
        <body style="font-family:system-ui;text-align:center;padding:2rem"><p>❌ ${msg}</p></body></html>
      `);
    }

    return res.json({
      success: true,
      data: updated,
      message: tenantConfirmed ? 'Visit confirmed by tenant' : 'Visit declined by tenant',
    });
  } catch (error) {
    logger.error('Error processing tenant confirmation:', error);
    res.status(500).json({
      success: false,
      error: { message: 'Internal server error', code: 'CONFIRMATION_FAILED' },
    });
  }
};

module.exports = {
  generateConfirmationToken,
  getConfirmationPage,
  submitConfirmation,
};
