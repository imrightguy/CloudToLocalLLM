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

function flush() {
  return cache.flushAll();
}

function getStats() {
  return cache.getStats();
}

module.exports = { cache, get, set, del, flush, getStats };
