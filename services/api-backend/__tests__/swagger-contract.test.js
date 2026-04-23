const swaggerSpec = require('../src/config/swagger');

function getParameter(path, method, name) {
  return swaggerSpec.paths[path][method].parameters.find((parameter) => parameter.name === name);
}

describe('Swagger contract regression coverage', () => {
  describe('visit scheduling docs', () => {
    it('documents the live visit create payload', () => {
      const schema = swaggerSpec.paths['/api/visits'].post.requestBody.content['application/json'].schema;

      expect(schema.required).toEqual(expect.arrayContaining(['unitId', 'employeeId', 'leadId', 'dateTime']));
      expect(schema.required).not.toEqual(expect.arrayContaining(['buildingId', 'scheduledAt']));
      expect(schema.properties.dateTime).toMatchObject({ type: 'string', format: 'date-time' });
      expect(schema.properties.durationMinutes).toMatchObject({ type: 'integer', minimum: 1, maximum: 1440, default: 30 });
      expect(schema.properties.status.enum).toEqual(['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show']);
    });

    it('documents visit update and status fields used by the controller', () => {
      const updateSchema = swaggerSpec.paths['/api/visits/{id}'].put.requestBody.content['application/json'].schema;
      const statusSchema = swaggerSpec.paths['/api/visits/{id}/status'].patch.requestBody.content['application/json'].schema;

      expect(updateSchema.properties.dateTime).toMatchObject({ type: 'string', format: 'date-time' });
      expect(updateSchema.properties.durationMinutes).toMatchObject({ type: 'integer', minimum: 1, maximum: 1440 });
      expect(updateSchema.properties.outcome.enum).toEqual(['interesse', 'pas_interesse', 'no_show']);
      expect(updateSchema.properties.tenantConfirmed).toMatchObject({ type: 'boolean' });
      expect(statusSchema.properties.status.enum).toEqual(['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show']);
      expect(statusSchema.properties.outcome.enum).toEqual(['interesse', 'pas_interesse', 'no_show']);
    });

    it('documents the shared Visit schema with dateTime and durationMinutes', () => {
      const schema = swaggerSpec.components.schemas.Visit;

      expect(schema.properties.dateTime).toMatchObject({ type: 'string', format: 'date-time' });
      expect(schema.properties.durationMinutes).toMatchObject({ type: 'integer' });
      expect(schema.properties.status.enum).toEqual(['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show']);
      expect(schema.properties.outcome.enum).toEqual(['interesse', 'pas_interesse', 'no_show']);
      expect(schema.properties.scheduledAt).toBeUndefined();
      expect(schema.properties.buildingId).toBeUndefined();
    });
  });

  describe('marketplace communication docs', () => {
    it('documents list filters for Messenger workflows', () => {
      expect(getParameter('/api/communications', 'get', 'employeeId')).toMatchObject({
        name: 'employeeId',
        schema: { type: 'string', format: 'uuid' },
      });
      expect(getParameter('/api/communications', 'get', 'direction').schema.enum).toEqual(['inbound', 'outbound']);
      expect(getParameter('/api/communications', 'get', 'status').schema.type).toBe('string');
      expect(getParameter('/api/communications', 'get', 'type').schema.enum).toEqual(['email', 'phone', 'sms', 'fb_messenger']);

      expect(getParameter('/api/communications/logs', 'get', 'employeeId')).toMatchObject({
        name: 'employeeId',
        schema: { type: 'string', format: 'uuid' },
      });
      expect(getParameter('/api/communications/logs', 'get', 'type').schema.enum).toEqual(['email', 'phone', 'sms', 'fb_messenger']);
      expect(getParameter('/api/communications/activity', 'get', 'hoursAgo')).toMatchObject({
        name: 'hoursAgo',
        schema: { type: 'integer', default: 168 },
      });
    });

    it('documents logging Messenger communications without requiring leadId', () => {
      const schema = swaggerSpec.paths['/api/communications'].post.requestBody.content['application/json'].schema;

      expect(schema.required).toEqual(expect.arrayContaining(['type', 'direction']));
      expect(schema.required).not.toContain('leadId');
      expect(schema.properties.employeeId).toMatchObject({ type: 'string', format: 'uuid', nullable: true });
      expect(schema.properties.leadId).toMatchObject({ type: 'string', format: 'uuid', nullable: true });
      expect(schema.properties.type.enum).toEqual(['email', 'phone', 'sms', 'fb_messenger']);
      expect(schema.properties.attachments).toMatchObject({ type: 'array' });
      expect(schema.properties.metadata).toMatchObject({ type: 'object', additionalProperties: true });
      expect(schema.properties.status.type).toBe('string');
    });

    it('documents the shared Communication schema for Messenger logs', () => {
      const schema = swaggerSpec.components.schemas.Communication;

      expect(schema.properties.employeeId).toMatchObject({ type: 'string', format: 'uuid', nullable: true });
      expect(schema.properties.type.enum).toEqual(['email', 'phone', 'sms', 'fb_messenger']);
      expect(schema.properties.attachments).toMatchObject({ type: 'array' });
      expect(schema.properties.metadata).toMatchObject({ type: 'object', additionalProperties: true });
      expect(schema.properties.status.type).toBe('string');
    });
  });
});
