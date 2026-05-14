const { env } = require('../config/env');

const cache = new Map();
const inflight = new Map();

const nowSeconds = () => Math.floor(Date.now() / 1000);

const getCached = (key) => {
  const entry = cache.get(key);
  if (!entry) return undefined;

  if (entry.expiresAt <= nowSeconds()) {
    cache.delete(key);
    return undefined;
  }

  return entry.value;
};

const setCached = (key, value, ttl) => {
  cache.set(key, {
    value,
    expiresAt: nowSeconds() + ttl
  });
};

const getOrSet = async (key, fetcher, ttl = env.cacheTtlSeconds) => {
  const cached = getCached(key);
  if (cached !== undefined) return cached;

  if (inflight.has(key)) return inflight.get(key);

  const pending = fetcher()
    .then((data) => {
      setCached(key, data, ttl);
      return data;
    })
    .finally(() => {
      inflight.delete(key);
    });

  inflight.set(key, pending);
  return pending;
};

module.exports = { getOrSet };
