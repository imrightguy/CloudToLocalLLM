const COMMUNICATION_STATUSES = new Set(['sent', 'delivered', 'read', 'failed', 'received']);

function normalizeCommunicationText(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed || null;
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    const normalized = String(value).trim();
    return normalized || null;
  }

  if (typeof value === 'object') {
    try {
      const serialized = JSON.stringify(value);
      return serialized || null;
    } catch {
      return null;
    }
  }

  const normalized = String(value).trim();
  return normalized || null;
}

function normalizeCommunicationStatus(value, fallback = 'sent') {
  if (typeof value !== 'string') {
    return fallback;
  }

  const trimmed = value.trim();
  return COMMUNICATION_STATUSES.has(trimmed) ? trimmed : fallback;
}

function isCommunicationStatusConstraintError(error) {
  if (!error || error.code !== '23514') {
    return false;
  }

  const haystack = [
    error.constraint,
    error.message,
    error.detail,
    error.where,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();

  if (haystack.includes('communication_logs_status_check')) {
    return true;
  }

  return haystack.includes('communication_logs') && haystack.includes('status');
}

function normalizeCommunicationAttachments(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeCommunicationMetadata(value) {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value;
  }

  return {};
}

module.exports = {
  normalizeCommunicationText,
  normalizeCommunicationStatus,
  normalizeCommunicationAttachments,
  normalizeCommunicationMetadata,
  isCommunicationStatusConstraintError,
};
