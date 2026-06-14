const NodeCache = require('node-cache');

const cache = new NodeCache({ stdTTL: 300, checkperiod: 60 });

function get(key) {
  return cache.get(key);
}

function set(key, value, ttl) {
  return cache.set(key, value, ttl);
}

function del(key) {
  return cache.del(key);
}

function patternToRegExp(pattern) {
  const escaped = pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\\\*/g, '.*');
  return new RegExp(`^${escaped}$`);
}

function invalidate(pattern) {
  if (!pattern.includes('*')) {
    return cache.del(pattern);
  }
  const regex = patternToRegExp(pattern);
  const matched = cache.keys().filter((key) => regex.test(key));
  return cache.del(matched);
}

function flush() {
  return cache.flushAll();
}

function getStats() {
  return cache.getStats();
}

module.exports = {
  cache, get, set, del, invalidate, flush, getStats,
};
