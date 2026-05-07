const { IncomingForm } = require('formidable');

const pickFirstValue = (value) => {
  if (Array.isArray(value)) {
    return value.length > 0 ? value[0] : undefined;
  }

  return value;
};

const normalizeMultipartValue = (key, value) => {
  const firstValue = pickFirstValue(value);

  if (firstValue === undefined) {
    return undefined;
  }

  if (firstValue === '' && key !== 'roomContext') {
    return undefined;
  }

  if (key === 'metadata' && typeof firstValue === 'string') {
    try {
      return JSON.parse(firstValue);
    } catch {
      return firstValue;
    }
  }

  return firstValue;
};

const pickFirstFile = (files) => {
  if (!files || typeof files !== 'object') {
    return null;
  }

  const fileEntries = Object.values(files)
    .flatMap((value) => (Array.isArray(value) ? value : [value]))
    .filter(Boolean);

  return fileEntries[0] || null;
};

const parsePropertyPhotoUpload = (req, res, next) => {
  if (!req.is('multipart/form-data')) {
    return next();
  }

  const form = new IncomingForm({
    multiples: false,
    keepExtensions: true,
    allowEmptyFiles: false,
    maxFileSize: 25 * 1024 * 1024,
  });

  form.parse(req, (error, fields, files) => {
    if (error) {
      return next(error);
    }

    req.body = Object.fromEntries(
      Object.entries(fields).map(([key, value]) => [key, normalizeMultipartValue(key, value)]),
    );
    req.photoUpload = pickFirstFile(files);

    return next();
  });
};

module.exports = {
  parsePropertyPhotoUpload,
};
