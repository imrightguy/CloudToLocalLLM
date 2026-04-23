const validate = require('../src/middleware/validate');
const Joi = require('joi');
const { communicationSchemas, visitSchemas } = require('../src/config/validation-schemas');

function mockReqRes(body = {}, query = {}, params = {}) {
  const res = {};
  const next = jest.fn();
  return { req: { body, query, params }, res, next };
}

describe('validate middleware', () => {
  it('calls next() when no validation errors', () => {
    const schema = {
      body: Joi.object({ name: Joi.string().required() }),
    };
    const { req, res, next } = mockReqRes({ name: 'test' });

    validate(schema)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toEqual({ name: 'test' });
  });

  it('calls next with ValidationError for invalid body', () => {
    const schema = {
      body: Joi.object({ name: Joi.string().required() }),
    };
    const { req, res, next } = mockReqRes({});

    validate(schema)(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    const error = next.mock.calls[0][0];
    expect(error.name).toBe('ValidationError');
    expect(error.message).toBe('Validation failed');
    expect(error.details.body).toBeDefined();
    expect(error.details.body[0].field).toBe('name');
  });

  it('validates query parameters', () => {
    const schema = {
      query: Joi.object({ page: Joi.number().min(1) }),
    };
    const { req, res, next } = mockReqRes({}, { page: 'abc' });

    validate(schema)(req, res, next);

    const error = next.mock.calls[0][0];
    expect(error.name).toBe('ValidationError');
    expect(error.details.query).toBeDefined();
  });

  it('validates route params', () => {
    const schema = {
      params: Joi.object({ id: Joi.number().required() }),
    };
    const { req, res, next } = mockReqRes({}, {}, { id: 'not-a-number' });

    validate(schema)(req, res, next);

    const error = next.mock.calls[0][0];
    expect(error.name).toBe('ValidationError');
    expect(error.details.params).toBeDefined();
  });

  it('handles multiple validation sources simultaneously', () => {
    const schema = {
      body: Joi.object({ name: Joi.string().required() }),
      query: Joi.object({ page: Joi.number().min(1) }),
    };
    const { req, res, next } = mockReqRes({}, { page: '-1' });

    validate(schema)(req, res, next);

    const error = next.mock.calls[0][0];
    expect(error.details.body).toBeDefined();
    expect(error.details.query).toBeDefined();
  });

  it('strips unknown fields from validated values', () => {
    const schema = {
      body: Joi.object({ name: Joi.string() }),
    };
    const { req, res, next } = mockReqRes({ name: 'test', extra: 'removed' });

    validate(schema)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toEqual({ name: 'test' });
    expect(req.body.extra).toBeUndefined();
  });

  it('collects all errors when abortEarly is false', () => {
    const schema = {
      body: Joi.object({
        name: Joi.string().required(),
        email: Joi.string().email().required(),
        age: Joi.number().min(0).required(),
      }),
    };
    const { req, res, next } = mockReqRes({ age: 'not-a-number' });

    validate(schema)(req, res, next);

    const error = next.mock.calls[0][0];
    expect(error.details.body.length).toBeGreaterThanOrEqual(2);
  });

  it('passes through with no schema properties', () => {
    const { req, res, next } = mockReqRes({ anything: 'goes' });

    validate({})(req, res, next);

    expect(next).toHaveBeenCalledWith();
  });

  it('replaces validated values on req object', () => {
    const schema = {
      body: Joi.object({ count: Joi.number() }),
      query: Joi.object({ limit: Joi.number() }),
      params: Joi.object({ id: Joi.number() }),
    };
    const { req, res, next } = mockReqRes(
      { count: '5' },
      { limit: '10' },
      { id: '42' },
    );

    validate(schema)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body.count).toBe(5);
    expect(req.query.limit).toBe(10);
    expect(req.params.id).toBe(42);
  });

  it('maps error details with field, message, and type', () => {
    const schema = {
      body: Joi.object({ email: Joi.string().email().required() }),
    };
    const { req, res, next } = mockReqRes({ email: 'not-email' });

    validate(schema)(req, res, next);

    const error = next.mock.calls[0][0];
    const detail = error.details.body[0];
    expect(detail).toHaveProperty('field');
    expect(detail).toHaveProperty('message');
    expect(detail).toHaveProperty('type');
  });

  it('accepts visit creation payloads used by the visit controller', () => {
    const futureDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const { req, res, next } = mockReqRes({
      unitId: '550e8400-e29b-41d4-a716-446655440000',
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      leadId: '550e8400-e29b-41d4-a716-446655440002',
      dateTime: futureDate,
      durationMinutes: 45,
      notes: 'Visite du samedi',
    });

    validate(visitSchemas.create)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toMatchObject({
      unitId: '550e8400-e29b-41d4-a716-446655440000',
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      leadId: '550e8400-e29b-41d4-a716-446655440002',
      durationMinutes: 45,
      notes: 'Visite du samedi',
    });
    expect(req.body.dateTime).toBeInstanceOf(Date);
    expect(req.body.dateTime.toISOString()).toBe(futureDate);
  });

  it('accepts visit rescheduling payloads used by the visit controller', () => {
    const futureDate = new Date(Date.now() + 8 * 24 * 60 * 60 * 1000).toISOString();
    const { req, res, next } = mockReqRes(
      {
        dateTime: futureDate,
        employeeId: '550e8400-e29b-41d4-a716-446655440001',
        durationMinutes: 60,
        notes: 'Reporter à 15h',
      },
      {},
      { id: '550e8400-e29b-41d4-a716-446655440004' },
    );

    validate(visitSchemas.update)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toMatchObject({
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      durationMinutes: 60,
      notes: 'Reporter à 15h',
    });
    expect(req.body.dateTime).toBeInstanceOf(Date);
    expect(req.body.dateTime.toISOString()).toBe(futureDate);
  });

  it('accepts confirmed as a valid visit status update', () => {
    const { req, res, next } = mockReqRes(
      { status: 'confirmed', outcome: 'interesse' },
      {},
      { id: '550e8400-e29b-41d4-a716-446655440003' },
    );

    validate(visitSchemas.updateStatus)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toEqual({ status: 'confirmed', outcome: 'interesse' });
  });

  it('accepts marketplace Messenger communication logs without a leadId', () => {
    const { req, res, next } = mockReqRes({
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Bonjour, la propriété est-elle disponible?',
    });

    validate(communicationSchemas.log)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toMatchObject({
      type: 'fb_messenger',
      direction: 'inbound',
      content: 'Bonjour, la propriété est-elle disponible?',
    });
    expect(req.body.attachments).toEqual([]);
    expect(req.body.metadata).toEqual({});
  });

  it('accepts filtering communications by marketplace Messenger type', () => {
    const { req, res, next } = mockReqRes({}, { type: 'fb_messenger', page: '2', limit: '25' });

    validate(communicationSchemas.list)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.query).toEqual({ type: 'fb_messenger', page: 2, limit: 25 });
  });
});
