const {
  templateSchema,
  updateTemplateSchema,
  campaignSchema,
  updateCampaignSchema,
  activateCampaignSchema,
} = require('../src/models/sms-campaign');

describe('sms-campaign models', () => {
  describe('templateSchema', () => {
    it('should validate a valid template', () => {
      const { error } = templateSchema.validate({
        name: 'Visit Reminder',
        body: 'Bonjour {{tenant_name}}',
        category: 'visit_reminder',
      });
      expect(error).toBeUndefined();
    });

    it('should require name', () => {
      const { error } = templateSchema.validate({
        body: 'test',
        category: 'custom',
      });
      expect(error).toBeDefined();
      expect(error.details[0].message).toContain('name');
    });

    it('should require body', () => {
      const { error } = templateSchema.validate({
        name: 'Test',
        category: 'custom',
      });
      expect(error).toBeDefined();
    });

    it('should require category', () => {
      const { error } = templateSchema.validate({
        name: 'Test',
        body: 'test body',
      });
      expect(error).toBeDefined();
    });

    it('should reject invalid category', () => {
      const { error } = templateSchema.validate({
        name: 'Test',
        body: 'test',
        category: 'invalid',
      });
      expect(error).toBeDefined();
    });

    it('should reject invalid language', () => {
      const { error } = templateSchema.validate({
        name: 'Test',
        body: 'test',
        category: 'custom',
        language: 'es',
      });
      expect(error).toBeDefined();
    });

    it('should default language to fr', () => {
      const { value } = templateSchema.validate({
        name: 'Test',
        body: 'test',
        category: 'custom',
      });
      expect(value.language).toBe('fr');
    });

    it('should accept en language', () => {
      const { error, value } = templateSchema.validate({
        name: 'Test',
        body: 'test',
        category: 'custom',
        language: 'en',
      });
      expect(error).toBeUndefined();
      expect(value.language).toBe('en');
    });

    it('should accept all valid categories', () => {
      const categories = ['visit_reminder', 'lease_renewal', 'payment_reminder', 'custom'];
      for (const cat of categories) {
        const { error } = templateSchema.validate({
          name: 'Test',
          body: 'test',
          category: cat,
        });
        expect(error).toBeUndefined();
      }
    });
  });

  describe('updateTemplateSchema', () => {
    it('should allow partial updates', () => {
      const { error } = updateTemplateSchema.validate({ name: 'Updated' });
      expect(error).toBeUndefined();
    });

    it('should allow empty body', () => {
      const { error } = updateTemplateSchema.validate({});
      expect(error).toBeUndefined();
    });
  });

  describe('campaignSchema', () => {
    it('should validate a valid one-time campaign', () => {
      const { error } = campaignSchema.validate({
        name: 'Test Campaign',
        targetAudience: 'all_tenants',
        scheduleType: 'once',
        scheduledAt: new Date(Date.now() + 86400000).toISOString(),
      });
      expect(error).toBeUndefined();
    });

    it('should validate a valid recurring campaign', () => {
      const { error } = campaignSchema.validate({
        name: 'Recurring Campaign',
        targetAudience: 'building_tenants',
        scheduleType: 'recurring',
        cronExpression: '0 9 1 * *',
      });
      expect(error).toBeUndefined();
    });

    it('should require name', () => {
      const { error } = campaignSchema.validate({
        targetAudience: 'all_tenants',
      });
      expect(error).toBeDefined();
    });

    it('should require targetAudience', () => {
      const { error } = campaignSchema.validate({
        name: 'Test',
      });
      expect(error).toBeDefined();
    });

    it('should reject invalid targetAudience', () => {
      const { error } = campaignSchema.validate({
        name: 'Test',
        targetAudience: 'everyone',
      });
      expect(error).toBeDefined();
    });

    it('should require cronExpression for recurring', () => {
      const { error } = campaignSchema.validate({
        name: 'Test',
        targetAudience: 'all_tenants',
        scheduleType: 'recurring',
      });
      expect(error).toBeDefined();
    });

    it('should require scheduledAt for one-time campaigns', () => {
      const { error } = campaignSchema.validate({
        name: 'Test',
        targetAudience: 'all_tenants',
        scheduleType: 'once',
      });
      expect(error).toBeDefined();
    });

    it('should reject past scheduledAt for one-time campaigns', () => {
      const { error } = campaignSchema.validate({
        name: 'Test',
        targetAudience: 'all_tenants',
        scheduleType: 'once',
        scheduledAt: new Date(Date.now() - 86400000).toISOString(),
      });
      expect(error).toBeDefined();
    });

    it('should accept all valid audiences', () => {
      const audiences = ['all_tenants', 'building_tenants', 'specific_leads'];
      for (const audience of audiences) {
        const { error } = campaignSchema.validate({
          name: 'Test',
          targetAudience: audience,
          scheduleType: 'once',
          scheduledAt: new Date(Date.now() + 86400000).toISOString(),
        });
        expect(error).toBeUndefined();
      }
    });
  });

  describe('updateCampaignSchema', () => {
    it('should allow partial updates', () => {
      const { error } = updateCampaignSchema.validate({ name: 'Updated' });
      expect(error).toBeUndefined();
    });

    it('should allow empty body', () => {
      const { error } = updateCampaignSchema.validate({});
      expect(error).toBeUndefined();
    });
  });

  describe('activateCampaignSchema', () => {
    it('should accept active', () => {
      const { error } = activateCampaignSchema.validate({ status: 'active' });
      expect(error).toBeUndefined();
    });

    it('should accept paused', () => {
      const { error } = activateCampaignSchema.validate({ status: 'paused' });
      expect(error).toBeUndefined();
    });

    it('should accept cancelled', () => {
      const { error } = activateCampaignSchema.validate({ status: 'cancelled' });
      expect(error).toBeUndefined();
    });

    it('should reject invalid status', () => {
      const { error } = activateCampaignSchema.validate({ status: 'draft' });
      expect(error).toBeDefined();
    });

    it('should require status', () => {
      const { error } = activateCampaignSchema.validate({});
      expect(error).toBeDefined();
    });
  });
});
