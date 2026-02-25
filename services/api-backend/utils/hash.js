/**
 * Hash utilities for CloudToLocalLLM API Backend
 */

import crypto from 'crypto';

/**
 * Generate SHA256 hash of a string
 * @param {string} str - String to hash
 * @returns {string} Hex-encoded hash
 */
export function sha256(str) {
  return crypto.createHash('sha256').update(str).digest('hex');
}

/**
 * Generate MD5 hash of a string
 * @param {string} str - String to hash
 * @returns {string} Hex-encoded hash
 */
export function md5(str) {
  return crypto.createHash('md5').update(str).digest('hex');
}

/**
 * Generate random hash
 * @returns {string} Random hex hash
 */
export function randomHash() {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Generic hash function (defaults to SHA256)
 * @param {string} str - String to hash
 * @param {string} algorithm - Hash algorithm (default: sha256)
 * @returns {string} Hex-encoded hash
 */
export function hash(str, algorithm = 'sha256') {
  return crypto.createHash(algorithm).update(str).digest('hex');
}

export default {
  sha256,
  md5,
  randomHash,
  hash,
};
