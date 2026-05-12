require('dotenv').config();

const required = (name) => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
};

const splitOrigins = (value) => {
  if (!value || value === '*') return true;
  return value.split(',').map((origin) => origin.trim()).filter(Boolean);
};

const env = {
  port: Number(process.env.PORT || 4000),
  tmdbApiKey: required('TMDB_API_KEY'),
  tmdbBaseUrl: process.env.TMDB_BASE_URL || 'https://api.themoviedb.org/3',
  allowedOrigins: splitOrigins(process.env.ALLOWED_ORIGINS || '*'),
  cacheTtlSeconds: Number(process.env.CACHE_TTL_SECONDS || 900),
  staleCacheTtlSeconds: Number(process.env.STALE_CACHE_TTL_SECONDS || 21600),
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 60000),
  rateLimitMax: Number(process.env.RATE_LIMIT_MAX || 120),
  requestTimeoutMs: Number(process.env.REQUEST_TIMEOUT_MS || 8000),
  streamProvider: process.env.STREAM_PROVIDER || 'disabled',
  videasyBaseUrl: process.env.VIDEASY_BASE_URL || '',
  vidsrcBaseUrl: process.env.VIDSRC_BASE_URL || '',
  isProduction: process.env.NODE_ENV === 'production'
};

module.exports = { env };
