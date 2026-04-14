class AppError extends Error {
  constructor({ message, code, statusCode, details }) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    this.isOperational = true;
  }

  static badRequest({ message = 'Bad request', code = 'BAD_REQUEST', details }) {
    return new AppError({ message, code, statusCode: 400, details });
  }

  static unauthorized({ message = 'Unauthorized', code = 'UNAUTHORIZED' }) {
    return new AppError({ message, code, statusCode: 401 });
  }

  static forbidden({ message = 'Forbidden', code = 'FORBIDDEN' }) {
    return new AppError({ message, code, statusCode: 403 });
  }

  static notFound({ message = 'Resource not found', code = 'NOT_FOUND' }) {
    return new AppError({ message, code, statusCode: 404 });
  }

  static conflict({ message = 'Conflict', code = 'CONFLICT' }) {
    return new AppError({ message, code, statusCode: 409 });
  }

  static validationError({ message = 'Validation failed', code = 'VALIDATION_ERROR', details }) {
    return new AppError({ message, code, statusCode: 400, details });
  }

  static tooManyRequests({ message = 'Too many requests', code = 'RATE_LIMIT_EXCEEDED' }) {
    return new AppError({ message, code, statusCode: 429 });
  }

  static internal({ message = 'Internal server error', code = 'INTERNAL_ERROR' }) {
    return new AppError({ message, code, statusCode: 500 });
  }
}

module.exports = AppError;
