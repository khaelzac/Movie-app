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

const splitList = (value) => {
  if (!value) return [];
  return value.split(',').map((item) => item.trim()).filter(Boolean);
};

const boolValue = (value, fallback = false) => {
  if (value === undefined || value === null || value === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).trim().toLowerCase());
};

const envValue = (name) => {
  const key = Object.keys(process.env).find((item) => item.toLowerCase() === name.toLowerCase());
  return key ? String(process.env[key]).trim() : '';
};

const numberedEmbedProviders = () => {
  const indexes = new Set();
  for (const key of Object.keys(process.env)) {
    const match = key.match(/^authorized_embed_provider_(\d+)_(name|base_url|movie_pattern|tv_pattern|resolver)$/i);
    if (match) indexes.add(Number(match[1]));
  }

  return [...indexes]
    .sort((a, b) => a - b)
    .map((index) => normalizeEmbedProvider({
      id: `env-${index}`,
      name: envValue(`AUTHORIZED_EMBED_PROVIDER_${index}_NAME`) || `Server ${index}`,
      baseUrl: envValue(`AUTHORIZED_EMBED_PROVIDER_${index}_BASE_URL`),
      moviePattern: envValue(`AUTHORIZED_EMBED_PROVIDER_${index}_MOVIE_PATTERN`) || '/movie/{tmdb_id}',
      tvPattern: envValue(`AUTHORIZED_EMBED_PROVIDER_${index}_TV_PATTERN`) || '/tv/{tmdb_id}/{season}/{episode}',
      resolver: envValue(`AUTHORIZED_EMBED_PROVIDER_${index}_RESOLVER`)
    }));
};

const hostnameFrom = (value) => {
  try {
    return new URL(value).hostname.replace(/^www\./, '').toLowerCase();
  } catch (_error) {
    return '';
  }
};

const normalizeEmbedProvider = (provider) => {
  const host = hostnameFrom(provider.baseUrl);

  if (host === 'vidlink.pro') {
    return {
      ...provider,
      moviePattern: '/movie/{tmdb_id}',
      tvPattern: '/tv/{tmdb_id}/{season}/{episode}'
    };
  }

  if (host === 'vidsrc.cc') {
    const trimmedBaseUrl = provider.baseUrl.replace(/\/+$/, '');
    const baseUrl = /\/v[23]$/i.test(trimmedBaseUrl)
      ? trimmedBaseUrl
      : `${trimmedBaseUrl}/v2`;
    return {
      ...provider,
      baseUrl,
      moviePattern: '/embed/movie/{tmdb_id}',
      tvPattern: '/embed/tv/{tmdb_id}/{season}/{episode}'
    };
  }

  return provider;
};

const streamProxyBaseUrl = process.env.STREAM_PROXY_BASE_URL || '';

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
  streamResolveRetries: Number(process.env.STREAM_RESOLVE_RETRIES || 2),
  streamProxyBaseUrl,
  streamProxyEnabled: boolValue(process.env.STREAM_PROXY_ENABLED, Boolean(streamProxyBaseUrl)),
  streamResolverViaProxy: boolValue(process.env.STREAM_RESOLVER_VIA_PROXY, false),
  streamProvider: process.env.STREAM_PROVIDER || 'disabled',
  streamProviders: splitList(process.env.STREAM_PROVIDERS || ''),
  videasyBaseUrl: process.env.VIDEASY_BASE_URL || '',
  vidsrcBaseUrl: process.env.VIDSRC_BASE_URL || '',
  customEmbedName: process.env.CUSTOM_EMBED_NAME || 'Custom',
  customEmbedBaseUrl: process.env.CUSTOM_EMBED_BASE_URL || '',
  customEmbedMoviePattern: process.env.CUSTOM_EMBED_MOVIE_PATTERN || '/movie/{tmdb_id}',
  customEmbedTvPattern: process.env.CUSTOM_EMBED_TV_PATTERN || '/tv/{tmdb_id}/{season}/{episode}',
  authorizedEmbedProviders: numberedEmbedProviders(),
  isProduction: process.env.NODE_ENV === 'production'
};

module.exports = { env };
