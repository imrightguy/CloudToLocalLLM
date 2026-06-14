const { getMaintenanceCommandCenter } = require('../services/maintenance-command-center.service');
const maintenanceService = require('../services/maintenance.service');
const { child } = require('../utils/logger');

const log = child({ controller: 'maintenance' });

exports.getCommandCenter = async (req, res) => {
  try {
    const { buildingId = null, limit = 12 } = req.query;
    const data = await getMaintenanceCommandCenter({ buildingId, limit });

    return res.json({
      success: true,
      data,
      message: 'Tableau de bord de maintenance récupéré avec succès',
    });
  } catch (error) {
    log.error('Error fetching maintenance command center', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'MAINTENANCE_COMMAND_CENTER_FAILED' },
    });
  }
};

// ─── Maintenance Tickets ───

exports.getTickets = async (req, res) => {
  try {
    const { tickets, metadata } = await maintenanceService.listTickets(req.query);
    return res.json({ success: true, data: tickets, metadata });
  } catch (error) {
    log.error('Error listing maintenance tickets', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'MAINTENANCE_TICKETS_FETCH_FAILED' },
    });
  }
};

exports.getTicketById = async (req, res) => {
  try {
    const ticket = await maintenanceService.getTicket(req.params.id);
    if (!ticket) {
      return res.status(404).json({
        success: false,
        error: { message: 'Ticket introuvable', code: 'TICKET_NOT_FOUND' },
      });
    }
    return res.json({ success: true, data: ticket });
  } catch (error) {
    log.error('Error fetching maintenance ticket', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'MAINTENANCE_TICKET_FETCH_FAILED' },
    });
  }
};

exports.createTicket = async (req, res) => {
  try {
    const ticket = await maintenanceService.createTicket(req.body);
    return res.status(201).json({
      success: true,
      data: ticket,
      message: 'Ticket de maintenance créé avec succès',
    });
  } catch (error) {
    log.error('Error creating maintenance ticket', { error: error.message });
    if (error.code === '23503') {
      return res.status(400).json({
        success: false,
        error: { message: 'Ressource référencée introuvable', code: 'FOREIGN_KEY_VIOLATION' },
      });
    }
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'MAINTENANCE_TICKET_CREATE_FAILED' },
    });
  }
};

exports.updateTicket = async (req, res) => {
  try {
    const existing = await maintenanceService.getTicket(req.params.id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: { message: 'Ticket introuvable', code: 'TICKET_NOT_FOUND' },
      });
    }
    const ticket = await maintenanceService.updateTicket(req.params.id, req.body);
    return res.json({
      success: true,
      data: ticket,
      message: 'Ticket de maintenance mis à jour avec succès',
    });
  } catch (error) {
    log.error('Error updating maintenance ticket', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'MAINTENANCE_TICKET_UPDATE_FAILED' },
    });
  }
};

exports.receiveVapiWebhook = async (req, res) => {
  try {
    const expectedSecret = process.env.VAPI_WEBHOOK_SECRET;
    if (expectedSecret) {
      const provided = req.headers['x-vapi-secret'];
      if (provided !== expectedSecret) {
        return res.status(401).json({
          success: false,
          error: { message: 'Invalid webhook secret', code: 'UNAUTHORIZED' },
        });
      }
    }

    const { ticket, created } = await maintenanceService.ingestVapiWebhook(req.body || {});
    return res.status(created ? 201 : 200).json({
      success: true,
      data: { ticket, created },
      message: created ? 'Ticket créé depuis Vapi' : 'Ticket Vapi déjà existant',
    });
  } catch (error) {
    log.error('Error ingesting Vapi webhook', { error: error.message });
    return res.status(500).json({
      success: false,
      error: { message: 'Erreur interne du serveur', code: 'VAPI_INGEST_FAILED' },
    });
  }
};
