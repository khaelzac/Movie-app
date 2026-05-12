const { env } = require('../config/env');

const cacheHeaders = (seconds = env.cacheTtlSeconds) => (_req, res, next) => {
  res.set('Cache-Control', `public, max-age=${seconds}, stale-while-revalidate=${env.staleCacheTtlSeconds}`);
  next();
};

const noStore = (_req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
};

module.exports = { cacheHeaders, noStore };
