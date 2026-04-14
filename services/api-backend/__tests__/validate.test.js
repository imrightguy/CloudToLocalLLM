const validate = require('../src/middleware/validate');
const Joi = require('joi');

describe('validate middleware', () => {
  let req;
  let res;
  let next;

  beforeEach(() => {
    req = { body: {}, query: {}, params: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
    next = jest.fn();
  });

  it('calls next() when all validations pass', () => {
    const schema = {
      body: Joi.object({ name: Joi.string().required() }),
    };

    req.body = { name: 'test' };
    const middleware = validate(schema);
    middleware(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('returns ValidationError when body validation fails', () => {
    const schema = {
      body: Joi.object({ email: Joi.string().email().required() }),
    };

    req.body = { email: 'not-an-email' };
    const middleware = validate(schema);
    middleware(req, res, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({
      name: 'ValidationError',
      message: 'Validation failed',
    }));

    const error = next.mock.calls[0][0];
    expect(error.details.body).toBeDefined();
    expect(error.details.body[0].field).toBe('email');
  });

  it('returns ValidationError when query validation fails', () => {
    const schema = {
      query: Joi.object({ page: Joi.number().integer().min(1) }),
    };

    req.query = { page: 'abc' };
    const middleware = validate(schema);
    middleware(req, res, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({
      name: 'ValidationError',
    }));

    const error = next.mock.calls[0][0];
    expect(error.details.query).toBeDefined();
  });

  it('returns ValidationError when params validation fails', () => {
    const schema = {
      params: Joi.object({ id: Joi.string().uuid().required() }),
    };

    req.params = { id: 'not-a-uuid' };
    const middleware = validate(schema);
    middleware(req, res, next);

    expect(next).toHaveBeenCalledWith(expect.objectContaining({
      name: 'ValidationError',
    }));

    const error = next.mock.calls[0][0];
    expect(error.details.params).toBeDefined();
  });

  it('collects multiple validation errors across body and query', () => {
    const schema = {
      body: Joi.object({ name: Joi.string().required() }),
      query: Joi.object({ page: Joi.number().required() }),
    };

    req.body = {};
    req.query = {};
    const middleware = validate(schema);
    middleware(req, res, next);

    const error = next.mock.calls[0][0];
    expect(error.details.body).toBeDefined();
    expect(error.details.query).toBeDefined();
  });

  it('strips unknown fields from body (stripUnknown)', () => {
    const schema = {
      body: Joi.object({ name: Joi.string().required() }),
    };

    req.body = { name: 'test', extra: 'field' };
    const middleware = validate(schema);
    middleware(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body.extra).toBeUndefined();
    expect(req.body.name).toBe('test');
  });

  it('passes with empty schema', () => {
    const middleware = validate({});
    middleware(req, res, next);

    expect(next).toHaveBeenCalledWith();
  });

  it('handles nested field paths in error details', () => {
    const schema = {
      body: Joi.object({
        address: Joi.object({
          city: Joi.string().required(),
        }).required(),
      }),
    };

    req.body = { address: {} };
    const middleware = validate(schema);
    middleware(req, res, next);

    const error = next.mock.calls[0][0];
    expect(error.details.body[0].field).toBe('address.city');
  });

  it('collects all errors when abortEarly is false', () => {
    const schema = {
      body: Joi.object({
        email: Joi.string().email().required(),
        name: Joi.string().min(3).required(),
      }),
    };

    req.body = {};
    const middleware = validate(schema);
    middleware(req, res, next);

    const error = next.mock.calls[0][0];
    expect(error.details.body.length).toBe(2);
  });
});
