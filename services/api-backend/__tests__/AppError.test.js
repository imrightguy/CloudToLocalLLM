const AppError = require('../src/middleware/AppError');

describe('AppError', () => {
  it('creates an error with correct properties', () => {
    const err = new AppError({
      message: 'test error',
      code: 'TEST_ERROR',
      statusCode: 400,
      details: { field: 'email' },
    });

    expect(err).toBeInstanceOf(Error);
    expect(err).toBeInstanceOf(AppError);
    expect(err.name).toBe('AppError');
    expect(err.message).toBe('test error');
    expect(err.code).toBe('TEST_ERROR');
    expect(err.statusCode).toBe(400);
    expect(err.details).toEqual({ field: 'email' });
    expect(err.isOperational).toBe(true);
  });

  it('defaults optional properties', () => {
    const err = new AppError({ message: 'msg', code: 'CODE', statusCode: 500 });

    expect(err.details).toBeUndefined();
    expect(err.isOperational).toBe(true);
  });

  describe('static factory methods', () => {
    it('badRequest() returns 400 error', () => {
      const err = AppError.badRequest({ message: 'bad', code: 'BAD' });
      expect(err.statusCode).toBe(400);
      expect(err.code).toBe('BAD');
      expect(err.message).toBe('bad');
    });

    it('unauthorized() returns 401 error', () => {
      const err = AppError.unauthorized({ message: 'no auth' });
      expect(err.statusCode).toBe(401);
      expect(err.code).toBe('UNAUTHORIZED');
    });

    it('forbidden() returns 403 error', () => {
      const err = AppError.forbidden({ message: 'forbidden' });
      expect(err.statusCode).toBe(403);
    });

    it('notFound() returns 404 error', () => {
      const err = AppError.notFound({ message: 'gone', code: 'GONE' });
      expect(err.statusCode).toBe(404);
      expect(err.code).toBe('GONE');
    });

    it('conflict() returns 409 error', () => {
      const err = AppError.conflict({ message: 'dup' });
      expect(err.statusCode).toBe(409);
    });

    it('validationError() returns 400 error with details', () => {
      const details = [{ field: 'email', message: 'required' }];
      const err = AppError.validationError({ message: 'fail', details });
      expect(err.statusCode).toBe(400);
      expect(err.details).toEqual(details);
    });

    it('tooManyRequests() returns 429 error', () => {
      const err = AppError.tooManyRequests({ message: 'slow down' });
      expect(err.statusCode).toBe(429);
    });

    it('internal() returns 500 error', () => {
      const err = AppError.internal({ message: 'oops' });
      expect(err.statusCode).toBe(500);
    });

    it('factory methods use default messages', () => {
      const err = AppError.badRequest({});
      expect(err.message).toBe('Bad request');
      expect(err.code).toBe('BAD_REQUEST');

      const err2 = AppError.unauthorized({});
      expect(err2.message).toBe('Unauthorized');

      const err3 = AppError.notFound({});
      expect(err3.message).toBe('Resource not found');
    });
  });
});
