const validate = (schema) => (req, res, next) => {
  const { body, query, params } = schema;
  const errors = {};

  if (body) {
    const { error, value } = body.validate(req.body, {
      abortEarly: false,
      stripUnknown: true,
    });
    if (value !== undefined) {req.body = value;}
    if (error) {
      errors.body = error.details.map((d) => ({
        field: d.path.join('.'),
        message: d.message,
        type: d.type,
      }));
    }
  }

  if (query) {
    const { error, value } = query.validate(req.query, {
      abortEarly: false,
      stripUnknown: true,
    });
    if (value !== undefined) {req.query = value;}
    if (error) {
      errors.query = error.details.map((d) => ({
        field: d.path.join('.'),
        message: d.message,
        type: d.type,
      }));
    }
  }

  if (params) {
    const { error, value } = params.validate(req.params, {
      abortEarly: false,
      stripUnknown: true,
    });
    if (value !== undefined) {req.params = value;}
    if (error) {
      errors.params = error.details.map((d) => ({
        field: d.path.join('.'),
        message: d.message,
        type: d.type,
      }));
    }
  }

  if (Object.keys(errors).length > 0) {
    const error = new Error('Validation failed');
    error.name = 'ValidationError';
    error.details = errors;
    return next(error);
  }

  next();
};

module.exports = validate;
