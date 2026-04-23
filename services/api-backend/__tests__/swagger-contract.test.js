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
      expect(schema.properties.status.enum).toEqual(['scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show']);
    });

    it('documents visit update and status fields used by the controller', () => {
      const updateSchema = swaggerSpec.paths['/api/visits/{id}'].put.requestBody.content['application/json'].schema;
      const statusSchema = swaggerSpec.paths['/api/visits/{id}/status'].patch.requestBody.content['application/json'].schema;

      expect(updateSchema.properties.dateTime).toMatchObject({ type: 'string', format: 'date-time' });
      expect(updateSchema.properties.durationMinutes).toMatchObject({ type: 'integer', minimum: 1, maximum: 1440 });
      expect(updateSchema.properties.outcome.enum).toEqual(['interesse', 'pas_interesse', 'no_show']);
      expect(updateSchema.properties.tenantConfirmed).toMatchObject({ type: 'boolean' });
      expect(statusSchema.properties.status.enum).toEqual(['scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show']);
      expect(statusSchema.properties.outcome.enum).toEqual(['interesse', 'pas_interesse', 'no_show']);
    });

    it('documents visit list sorting options supported by the controller', () => {
      expect(getParameter('/api/visits', 'get', 'sortBy').schema.enum).toEqual([
        'dateTime',
        'createdAt',
        'status',
        'durationMinutes',
        'updatedAt',
      ]);
    });

    it('documents the visit list pagination envelope as metadata', () => {
      const visitListResponse = swaggerSpec.paths['/api/visits'].get.responses[200].content['application/json'].schema.allOf[1].properties;

      expect(visitListResponse.metadata).toMatchObject({
        $ref: '#/components/schemas/PaginationMeta',
      });
      expect(visitListResponse.meta).toBeUndefined();
    });

    it('documents the shared Visit schema with dateTime and durationMinutes', () => {
      const schema = swaggerSpec.components.schemas.Visit;

      expect(schema.properties.dateTime).toMatchObject({ type: 'string', format: 'date-time' });
      expect(schema.properties.durationMinutes).toMatchObject({ type: 'integer' });
      expect(schema.properties.status.enum).toEqual(['scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show']);
      expect(schema.properties.outcome.enum).toEqual(['interesse', 'pas_interesse', 'no_show']);
      expect(schema.properties.scheduledAt).toBeUndefined();
      expect(schema.properties.buildingId).toBeUndefined();
    });
  });

  describe('marketplace communication docs', () => {
    it('documents list filters and pagination envelope for Messenger workflows', () => {
      expect(getParameter('/api/communications', 'get', 'employeeId')).toMatchObject({
        name: 'employeeId',
        schema: { type: 'string', format: 'uuid' },
      });
      expect(getParameter('/api/communications', 'get', 'direction').schema.enum).toEqual(['inbound', 'outbound']);
      expect(getParameter('/api/communications', 'get', 'status').schema.type).toBe('string');
      expect(getParameter('/api/communications', 'get', 'type').schema.enum).toEqual(['email', 'phone', 'sms', 'fb_messenger']);

      const communicationListResponse = swaggerSpec.paths['/api/communications'].get.responses[200].content['application/json'].schema.allOf[1].properties;
      expect(communicationListResponse.metadata).toMatchObject({
        $ref: '#/components/schemas/PaginationMeta',
      });
      expect(communicationListResponse.meta).toBeUndefined();

      expect(getParameter('/api/communications/logs', 'get', 'employeeId')).toMatchObject({
        name: 'employeeId',
        schema: { type: 'string', format: 'uuid' },
      });
      expect(getParameter('/api/communications/logs', 'get', 'type').schema.enum).toEqual(['email', 'phone', 'sms', 'fb_messenger']);
      expect(getParameter('/api/communications/logs', 'get', 'direction').schema.enum).toEqual(['inbound', 'outbound']);
      expect(getParameter('/api/communications/logs', 'get', 'status').schema.type).toBe('string');

      const communicationLogsResponse = swaggerSpec.paths['/api/communications/logs'].get.responses[200].content['application/json'].schema.allOf[1].properties;
      expect(communicationLogsResponse.metadata).toMatchObject({
        $ref: '#/components/schemas/PaginationMeta',
      });
      expect(communicationLogsResponse.meta).toBeUndefined();

      expect(getParameter('/api/communications/activity', 'get', 'hoursAgo')).toMatchObject({
        name: 'hoursAgo',
        schema: { type: 'integer', default: 168 },
      });
      expect(getParameter('/api/communications/activity', 'get', 'type')).toMatchObject({
        name: 'type',
        schema: { type: 'string' },
      });

      const activityItem = swaggerSpec.paths['/api/communications/activity'].get.responses[200].content['application/json'].schema.allOf[1].properties.data.items.properties;
      expect(activityItem.timestamp).toMatchObject({ type: 'string', format: 'date-time' });
      expect(activityItem.description).toMatchObject({ type: 'string' });
      expect(activityItem.metadata).toMatchObject({ type: 'object', additionalProperties: true });
      expect(activityItem.createdAt).toBeUndefined();
      expect(activityItem.leadName).toBeUndefined();
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

    it('documents communication log updates with status, attachments, and metadata', () => {
      const schema = swaggerSpec.paths['/api/communications/logs/{id}'].put.requestBody.content['application/json'].schema;

      expect(schema.properties.subject).toMatchObject({ type: 'string' });
      expect(schema.properties.content).toMatchObject({ type: 'string' });
      expect(schema.properties.attachments).toMatchObject({ type: 'array' });
      expect(schema.properties.status).toMatchObject({
        type: 'string',
        enum: ['sent', 'delivered', 'read', 'failed'],
      });
      expect(schema.properties.metadata).toMatchObject({ type: 'object', additionalProperties: true });
      expect(schema.properties.type).toBeUndefined();
    });

    it('documents the shared Communication and pagination schemas for Messenger logs', () => {
      const schema = swaggerSpec.components.schemas.Communication;
      const paginationSchema = swaggerSpec.components.schemas.PaginationMeta;

      expect(schema.properties.employeeId).toMatchObject({ type: 'string', format: 'uuid', nullable: true });
      expect(schema.properties.type.enum).toEqual(['email', 'phone', 'sms', 'fb_messenger']);
      expect(schema.properties.attachments).toMatchObject({ type: 'array' });
      expect(schema.properties.metadata).toMatchObject({ type: 'object', additionalProperties: true });
      expect(schema.properties.status.type).toBe('string');

      expect(paginationSchema.properties).toMatchObject({
        total: { type: 'integer' },
        page: { type: 'integer' },
        limit: { type: 'integer' },
        totalPages: { type: 'integer' },
        hasMore: { type: 'boolean' },
      });
    });
  });
});
