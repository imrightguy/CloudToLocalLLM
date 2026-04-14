jest.mock('../src/database/connection', () => {
  const chain = {};
  chain.select = jest.fn(() => chain);
  chain.from = jest.fn(() => chain);
  chain.leftJoin = jest.fn(() => chain);
  chain.where = jest.fn(() => chain);
  chain.and = chain.where;
  chain.orderBy = jest.fn(() => chain);
  chain.limit = jest.fn(() => chain);
  chain.set = jest.fn(() => chain);
  chain.values = jest.fn(() => chain);
  chain.returning = jest.fn(() => Promise.resolve([{ id: 't1' }]));
  chain.insert = jest.fn(() => chain);
  chain.update = jest.fn(() => chain);
  return { db: chain };
});

jest.mock('../src/database/schema', () => ({
  smsTemplatesTable: { id: 'id', name: 'name', body: 'body', language: 'language', category: 'category', isActive: 'is_active' },
  smsCampaignsTable: { id: 'id', name: 'name', status: 'status', totalSent: 'total_sent', totalFailed: 'total_failed' },
  smsQueueTable: { id: 'id', visitId: 'visit_id', leaseId: 'lease_id', campaignId: 'campaign_id', reminderType: 'reminder_type', retryCount: 'retry_count', maxRetries: 'max_retries', scheduledAt: 'scheduled_at', status: 'status', createdAt: 'created_at' },
  visitsTable: { id: 'id', dateTime: 'date_time', status: 'status', isActive: 'is_active', tenantConfirmed: 'tenant_confirmed', morningOfSent: 'morning_of_sent', outcome: 'outcome' },
  leasesTable: { id: 'id', endDate: 'end_date', status: 'status', isActive: 'is_active', unitId: 'unit_id', startDate: 'start_date' },
  unitsTable: { id: 'id', buildingId: 'building_id', status: 'status', tenantPhone: 'tenant_phone', tenantName: 'tenant_name', label: 'label', rentCents: 'rent_cents' },
  buildingsTable: { id: 'id', address: 'address', city: 'city', name: 'name' },
  leadsTable: { id: 'id', phone: 'phone', fullName: 'full_name', buildingId: 'building_id', isActive: 'is_active' },
  employeesTable: {},
  smsLogsTable: {},
  usersTable: {},
}));

jest.mock('../src/services/twilio.service', () => ({
  sendSMS: jest.fn(),
  handleIncomingMessage: jest.fn(),
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

const { db } = require('../src/database/connection');
const { sendSMS } = require('../src/services/twilio.service');
const {
  renderTemplate,
  extractVariables,
  createTemplate,
  getTemplates,
  getTemplateById,
  updateTemplate,
  deleteTemplate,
  createCampaign,
  getCampaigns,
  getCampaignById,
  updateCampaign,
  setCampaignStatus,
  deleteCampaign,
  executeCampaign,
  processQueue,
} = require('../src/services/sms.service');

describe('sms.service - Template & Campaign', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('renderTemplate', () => {
    it('should replace {{variables}} with values', () => {
      const body = 'Bonjour {{tenant_name}}, votre visite est le {{visit_date}}.';
      const result = renderTemplate(body, {
        tenant_name: 'Jean',
        visit_date: '15 mai',
      });
      expect(result).toBe('Bonjour Jean, votre visite est le 15 mai.');
    });

    it('should replace multiple occurrences of the same variable', () => {
      const body = '{{name}} - {{name}} - confirmé';
      const result = renderTemplate(body, { name: 'Test' });
      expect(result).toBe('Test - Test - confirmé');
    });

    it('should leave unreplaced variables intact when value is missing', () => {
      const body = 'Bonjour {{tenant_name}} à {{building_address}}';
      const result = renderTemplate(body, { tenant_name: 'Jean' });
      expect(result).toBe('Bonjour Jean à {{building_address}}');
    });

    it('should handle empty variables object', () => {
      const body = 'No variables here';
      const result = renderTemplate(body, {});
      expect(result).toBe('No variables here');
    });
  });

  describe('extractVariables', () => {
    it('should extract unique variable names', () => {
      const body = 'Bonjour {{tenant_name}}, votre visite le {{visit_date}} à {{building_address}}.';
      const vars = extractVariables(body);
      expect(vars).toEqual(['tenant_name', 'visit_date', 'building_address']);
    });

    it('should deduplicate variables', () => {
      const body = '{{name}} and {{name}} again';
      const vars = extractVariables(body);
      expect(vars).toEqual(['name']);
    });

    it('should return empty array for no variables', () => {
      const vars = extractVariables('No variables here');
      expect(vars).toEqual([]);
    });
  });

  describe('createTemplate', () => {
    it('should insert template with extracted variables', async () => {
      db.insert.mockReturnValue({
        values: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{
            id: 't1', name: 'Visit Reminder', body: 'Bonjour {{tenant_name}}',
            language: 'fr', category: 'visit_reminder', variables: ['tenant_name'],
          }]),
        }),
      });

      const result = await createTemplate({
        name: 'Visit Reminder',
        body: 'Bonjour {{tenant_name}}',
        category: 'visit_reminder',
      });

      expect(result.name).toBe('Visit Reminder');
      expect(result.variables).toEqual(['tenant_name']);
    });
  });

  describe('getTemplates', () => {
    it('should return templates with filters', async () => {
      db.select.mockReturnValue({
        from: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            orderBy: jest.fn().mockResolvedValue([{ id: 't1' }]),
          }),
        }),
      });

      const results = await getTemplates({ category: 'visit_reminder' });
      expect(results).toHaveLength(1);
    });
  });

  describe('createCampaign', () => {
    it('should create campaign with draft status', async () => {
      db.insert.mockReturnValue({
        values: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{
            id: 'c1', name: 'Test Campaign', status: 'draft',
          }]),
        }),
      });

      const result = await createCampaign({
        name: 'Test Campaign',
        targetAudience: 'all_tenants',
        scheduleType: 'once',
        scheduledAt: new Date(Date.now() + 86400000).toISOString(),
      }, 'user1');

      expect(result.status).toBe('draft');
    });
  });

  describe('processQueue', () => {
    it('should process pending messages and send via Twilio', async () => {
      const mockMessages = [
        { id: 'q1', phoneNumber: '+15145550001', messageBody: 'Test', retryCount: 0, maxRetries: 3, campaignId: 'c1' },
      ];

      db.select.mockReturnValue({
        from: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            orderBy: jest.fn().mockReturnValue({
              limit: jest.fn().mockResolvedValue(mockMessages),
            }),
          }),
        }),
      });

      db.update.mockReturnValue({
        set: jest.fn().mockReturnValue({
          where: jest.fn().mockResolvedValue(undefined),
        }),
      });

      db.insert.mockReturnValue({
        values: jest.fn().mockResolvedValue(undefined),
      });

      sendSMS.mockResolvedValue({ success: true, sid: 'SM123', status: 'queued' });

      const result = await processQueue();
      expect(result.processed).toBe(1);
      expect(result.sent).toBe(1);
    });

    it('should handle send failure and schedule retry', async () => {
      const mockMessages = [
        { id: 'q2', phoneNumber: '+15145550002', messageBody: 'Fail', retryCount: 0, maxRetries: 3, campaignId: null, scheduledAt: new Date() },
      ];

      db.select.mockReturnValue({
        from: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            orderBy: jest.fn().mockReturnValue({
              limit: jest.fn().mockResolvedValue(mockMessages),
            }),
          }),
        }),
      });

      db.update.mockReturnValue({
        set: jest.fn().mockReturnValue({
          where: jest.fn().mockResolvedValue(undefined),
        }),
      });

      sendSMS.mockResolvedValue({ success: false, error: 'Twilio error' });

      const result = await processQueue();
      expect(result.processed).toBe(1);
      expect(result.failed).toBe(1);
    });
  });
});
