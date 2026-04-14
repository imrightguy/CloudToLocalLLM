jest.mock('../src/services/sms.service', () => ({
  createTemplate: jest.fn(),
  getTemplates: jest.fn(),
  getTemplateById: jest.fn(),
  updateTemplate: jest.fn(),
  deleteTemplate: jest.fn(),
  createCampaign: jest.fn(),
  getCampaigns: jest.fn(),
  getCampaignById: jest.fn(),
  updateCampaign: jest.fn(),
  setCampaignStatus: jest.fn(),
  deleteCampaign: jest.fn(),
  executeCampaign: jest.fn(),
  renderTemplate: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  child: jest.fn(() => ({
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  })),
}));

const express = require('express');
const request = require('supertest');
const smsService = require('../src/services/sms.service');
const controller = require('../src/controllers/sms-campaign.controller');

const createApp = (routePath, handler) => {
  const app = express();
  app.use(express.json());
  app.post(routePath, (req, res) => handler(req, res));
  app.get(routePath, (req, res) => handler(req, res));
  app.patch(routePath, (req, res) => handler(req, res));
  app.delete(routePath, (req, res) => handler(req, res));
  return app;
};

describe('sms-campaign.controller', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createTemplateHandler', () => {
    it('should create a template with valid data', async () => {
      smsService.createTemplate.mockResolvedValue({
        id: 't1', name: 'Visit Reminder', body: 'Bonjour {{tenant_name}}',
        language: 'fr', category: 'visit_reminder', variables: ['tenant_name'],
      });

      const app = createApp('/api/sms/templates', controller.createTemplateHandler);
      const res = await request(app)
        .post('/api/sms/templates')
        .send({
          name: 'Visit Reminder',
          body: 'Bonjour {{tenant_name}}',
          category: 'visit_reminder',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe('Visit Reminder');
    });

    it('should return 400 for invalid category', async () => {
      const app = createApp('/api/sms/templates', controller.createTemplateHandler);
      const res = await request(app)
        .post('/api/sms/templates')
        .send({
          name: 'Bad',
          body: 'test',
          category: 'invalid_category',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('should return 400 for missing name', async () => {
      const app = createApp('/api/sms/templates', controller.createTemplateHandler);
      const res = await request(app)
        .post('/api/sms/templates')
        .send({
          body: 'test',
          category: 'custom',
        });

      expect(res.status).toBe(400);
    });
  });

  describe('getTemplatesHandler', () => {
    it('should return templates filtered by category', async () => {
      smsService.getTemplates.mockResolvedValue([
        { id: 't1', name: 'Reminder', category: 'visit_reminder' },
      ]);

      const app = createApp('/api/sms/templates', controller.getTemplatesHandler);
      const res = await request(app)
        .get('/api/sms/templates?category=visit_reminder');

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(smsService.getTemplates).toHaveBeenCalledWith({ category: 'visit_reminder' });
    });

    it('should return templates without filters', async () => {
      smsService.getTemplates.mockResolvedValue([]);

      const app = createApp('/api/sms/templates', controller.getTemplatesHandler);
      const res = await request(app)
        .get('/api/sms/templates');

      expect(res.status).toBe(200);
      expect(smsService.getTemplates).toHaveBeenCalledWith({});
    });
  });

  describe('getTemplateByIdHandler', () => {
    it('should return 404 for non-existent template', async () => {
      smsService.getTemplateById.mockResolvedValue(null);

      const app = createApp('/api/sms/templates/:id', controller.getTemplateByIdHandler);
      const res = await request(app)
        .get('/api/sms/templates/nonexistent');

      expect(res.status).toBe(404);
    });

    it('should return template when found', async () => {
      smsService.getTemplateById.mockResolvedValue({
        id: 't1', name: 'Reminder', body: 'test',
      });

      const app = createApp('/api/sms/templates/:id', controller.getTemplateByIdHandler);
      const res = await request(app)
        .get('/api/sms/templates/t1');

      expect(res.status).toBe(200);
      expect(res.body.data.name).toBe('Reminder');
    });
  });

  describe('updateTemplateHandler', () => {
    it('should update template', async () => {
      smsService.getTemplateById.mockResolvedValue({ id: 't1' });
      smsService.updateTemplate.mockResolvedValue({
        id: 't1', name: 'Updated', body: 'new body',
      });

      const app = createApp('/api/sms/templates/:id', controller.updateTemplateHandler);
      const res = await request(app)
        .patch('/api/sms/templates/t1')
        .send({ name: 'Updated' });

      expect(res.status).toBe(200);
      expect(res.body.data.name).toBe('Updated');
    });

    it('should return 404 for non-existent template', async () => {
      smsService.getTemplateById.mockResolvedValue(null);

      const app = createApp('/api/sms/templates/:id', controller.updateTemplateHandler);
      const res = await request(app)
        .patch('/api/sms/templates/nonexistent')
        .send({ name: 'Updated Name' });

      expect(res.status).toBe(404);
    });
  });

  describe('deleteTemplateHandler', () => {
    it('should soft-delete template', async () => {
      smsService.getTemplateById.mockResolvedValue({ id: 't1' });
      smsService.deleteTemplate.mockResolvedValue({ id: 't1' });

      const app = createApp('/api/sms/templates/:id', controller.deleteTemplateHandler);
      const res = await request(app)
        .delete('/api/sms/templates/t1');

      expect(res.status).toBe(200);
      expect(smsService.deleteTemplate).toHaveBeenCalledWith('t1');
    });

    it('should return 404 for non-existent template', async () => {
      smsService.getTemplateById.mockResolvedValue(null);

      const app = createApp('/api/sms/templates/:id', controller.deleteTemplateHandler);
      const res = await request(app)
        .delete('/api/sms/templates/nonexistent');

      expect(res.status).toBe(404);
    });
  });

  describe('previewTemplateHandler', () => {
    it('should render template preview', async () => {
      smsService.renderTemplate.mockReturnValue('Bonjour Jean, visite le 15 mai.');

      const app = express();
      app.use(express.json());
      app.post('/preview', controller.previewTemplateHandler);

      const res = await request(app)
        .post('/preview')
        .send({
          body: 'Bonjour {{tenant_name}}, visite le {{visit_date}}.',
          variables: { tenant_name: 'Jean', visit_date: '15 mai' },
        });

      expect(res.status).toBe(200);
      expect(res.body.data.rendered).toBe('Bonjour Jean, visite le 15 mai.');
    });

    it('should return 400 without body', async () => {
      const app = express();
      app.use(express.json());
      app.post('/preview', controller.previewTemplateHandler);

      const res = await request(app)
        .post('/preview')
        .send({});

      expect(res.status).toBe(400);
    });
  });

  describe('createCampaignHandler', () => {
    it('should create a campaign', async () => {
      smsService.createCampaign.mockResolvedValue({
        id: 'c1', name: 'Test', status: 'draft',
      });

      const app = express();
      app.use(express.json());
      app.post('/campaigns', (req, res, next) => {
        req.user = { id: 'u1' };
        controller.createCampaignHandler(req, res, next);
      });

      const res = await request(app)
        .post('/campaigns')
        .send({
          name: 'Test',
          targetAudience: 'all_tenants',
          scheduleType: 'once',
          scheduledAt: new Date(Date.now() + 86400000).toISOString(),
        });

      expect(res.status).toBe(201);
      expect(res.body.data.status).toBe('draft');
    });

    it('should return 400 for invalid audience', async () => {
      const app = express();
      app.use(express.json());
      app.post('/campaigns', controller.createCampaignHandler);

      const res = await request(app)
        .post('/campaigns')
        .send({
          name: 'Test',
          targetAudience: 'invalid',
        });

      expect(res.status).toBe(400);
    });

    it('should require cronExpression for recurring campaigns', async () => {
      const app = express();
      app.use(express.json());
      app.post('/campaigns', controller.createCampaignHandler);

      const res = await request(app)
        .post('/campaigns')
        .send({
          name: 'Test',
          targetAudience: 'all_tenants',
          scheduleType: 'recurring',
        });

      expect(res.status).toBe(400);
    });
  });

  describe('getCampaignsHandler', () => {
    it('should return campaigns with filters', async () => {
      smsService.getCampaigns.mockResolvedValue([
        { id: 'c1', name: 'Campaign 1', status: 'active' },
      ]);

      const app = createApp('/campaigns', controller.getCampaignsHandler);
      const res = await request(app)
        .get('/campaigns?status=active');

      expect(res.status).toBe(200);
      expect(smsService.getCampaigns).toHaveBeenCalledWith({ status: 'active' });
    });
  });

  describe('getCampaignByIdHandler', () => {
    it('should return 404 for non-existent campaign', async () => {
      smsService.getCampaignById.mockResolvedValue(null);

      const app = createApp('/campaigns/:id', controller.getCampaignByIdHandler);
      const res = await request(app)
        .get('/campaigns/nonexistent');

      expect(res.status).toBe(404);
    });
  });

  describe('updateCampaignHandler', () => {
    it('should not allow updating completed campaigns', async () => {
      smsService.getCampaignById.mockResolvedValue({ id: 'c1', status: 'completed' });

      const app = createApp('/campaigns/:id', controller.updateCampaignHandler);
      const res = await request(app)
        .patch('/campaigns/c1')
        .send({ name: 'New Name' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('CAMPAIGN_FINALIZED');
    });
  });

  describe('activateCampaignHandler', () => {
    it('should activate a campaign', async () => {
      smsService.getCampaignById.mockResolvedValue({ id: 'c1', status: 'draft' });
      smsService.setCampaignStatus.mockResolvedValue({ id: 'c1', status: 'active' });

      const app = express();
      app.use(express.json());
      app.post('/campaigns/:id/activate', controller.activateCampaignHandler);

      const res = await request(app)
        .post('/campaigns/c1/activate')
        .send({ status: 'active' });

      expect(res.status).toBe(200);
      expect(smsService.setCampaignStatus).toHaveBeenCalledWith('c1', 'active');
    });

    it('should return 400 for invalid status', async () => {
      const app = express();
      app.use(express.json());
      app.post('/campaigns/:id/activate', controller.activateCampaignHandler);

      const res = await request(app)
        .post('/campaigns/c1/activate')
        .send({ status: 'invalid' });

      expect(res.status).toBe(400);
    });
  });

  describe('executeCampaignHandler', () => {
    it('should execute a campaign', async () => {
      smsService.getCampaignById.mockResolvedValue({ id: 'c1', status: 'active' });
      smsService.executeCampaign.mockResolvedValue({ success: true, processed: 10 });

      const app = express();
      app.use(express.json());
      app.post('/campaigns/:id/execute', controller.executeCampaignHandler);

      const res = await request(app)
        .post('/campaigns/c1/execute');

      expect(res.status).toBe(200);
      expect(res.body.data.processed).toBe(10);
    });

    it('should return 404 for non-existent campaign', async () => {
      smsService.getCampaignById.mockResolvedValue(null);

      const app = express();
      app.use(express.json());
      app.post('/campaigns/:id/execute', controller.executeCampaignHandler);

      const res = await request(app)
        .post('/campaigns/nonexistent/execute');

      expect(res.status).toBe(404);
    });
  });

  describe('deleteCampaignHandler', () => {
    it('should delete a campaign', async () => {
      smsService.getCampaignById.mockResolvedValue({ id: 'c1' });
      smsService.deleteCampaign.mockResolvedValue(undefined);

      const app = createApp('/campaigns/:id', controller.deleteCampaignHandler);
      const res = await request(app)
        .delete('/campaigns/c1');

      expect(res.status).toBe(200);
    });
  });
});
