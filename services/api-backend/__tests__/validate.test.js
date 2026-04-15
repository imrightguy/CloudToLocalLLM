const validate = require('../src/middleware/validate');
const Joi = require('joi');

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
});
