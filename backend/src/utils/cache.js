const NodeCache = require('node-cache');
const { env } = require('../config/env');

const cache = new NodeCache({
  stdTTL: env.cacheTtlSeconds,
  checkperiod: Math.max(60, Math.floor(env.cacheTtlSeconds / 2)),
  useClones: false
});

const inflight = new Map();

const getOrSet = async (key, fetcher, ttl = env.cacheTtlSeconds) => {
  const cached = cache.get(key);
  if (cached) return cached;

  if (inflight.has(key)) return inflight.get(key);

  const pending = fetcher()
    .then((data) => {
      cache.set(key, data, ttl);
      return data;
    })
    .finally(() => {
      inflight.delete(key);
    });

  inflight.set(key, pending);
  return pending;
};

module.exports = { cache, getOrSet };
