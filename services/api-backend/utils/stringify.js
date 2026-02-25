/**
 * String utilities for CloudToLocalLLM API Backend
 */

/**
 * Safely stringify an object
 * @param {*} obj - Object to stringify
 * @param {number} space - Indentation spaces
 * @returns {string} JSON string
 */
export function stringify(obj, space = 2) {
  try {
    return JSON.stringify(obj, null, space);
  } catch {
    return String(obj);
  }
}

/**
 * Truncate a string to a maximum length
 * @param {string} str - String to truncate
 * @param {number} maxLength - Maximum length
 * @param {string} suffix - Suffix to add if truncated
 * @returns {string} Truncated string
 */
export function truncate(str, maxLength = 100, suffix = '...') {
  if (str.length <= maxLength) {
    return str;
  }
  return str.substring(0, maxLength - suffix.length) + suffix;
}

/**
 * Asynchronously stringify an object
 * @param {*} obj - Object to stringify
 * @param {number} space - Indentation spaces
 * @returns {Promise<string>} JSON string promise
 */
export async function asyncStringify(obj, space = 2) {
  return new Promise((resolve) => {
    try {
      resolve(JSON.stringify(obj, null, space));
    } catch {
      resolve(String(obj));
    }
  });
}

/**
 * Async toString method for objects
 * @param {*} obj - Object to convert to string
 * @returns {Promise<string>} String representation promise
 */
export async function asyncToStringMethod(obj) {
  return new Promise((resolve) => {
    try {
      if (obj && typeof obj.toString === 'function') {
        resolve(obj.toString());
      } else {
        resolve(String(obj));
      }
    } catch {
      resolve('[Object]');
    }
  });
}

/**
 * Synchronous toString method for objects
 * @param {*} obj - Object to convert to string
 * @returns {string} String representation
 */
export function toStringMethod(obj) {
  try {
    if (obj && typeof obj.toString === 'function') {
      return obj.toString();
    }
    return String(obj);
  } catch {
    return '[Object]';
  }
}

export default {
  stringify,
  truncate,
  asyncStringify,
  asyncToStringMethod,
  toStringMethod,
};
