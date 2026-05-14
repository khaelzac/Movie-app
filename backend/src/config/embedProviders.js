const envValue = (name, fallback = '') => {
  const key = Object.keys(process.env).find((item) => item.toLowerCase() === name.toLowerCase());
  return key ? String(process.env[key]).trim() : fallback;
};

const splitList = (value) => {
  if (!value) return [];
  return value.split(',').map((item) => item.trim()).filter(Boolean);
};

const boolValue = (value, fallback = true) => {
  if (value === undefined || value === null || value === '') return fallback;
  return ['1', 'true', 'yes', 'on', 'enabled'].includes(String(value).trim().toLowerCase());
};

const numberValue = (value, fallback) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const encodeValue = (value) => encodeURIComponent(String(value));

const renderPattern = (pattern, values) => pattern.replace(
  /\{(tmdb_id|season|episode)\}/g,
  (_match, key) => encodeValue(values[key])
);

const joinEmbedUrl = (baseUrl, pattern, values) => {
  if (!baseUrl) {
    const error = new Error('Embed provider base URL is not configured.');
    error.status = 501;
    throw error;
  }

  const normalizedBase = baseUrl.replace(/\/+$/, '');
  const normalizedPattern = pattern.startsWith('/') ? pattern : `/${pattern}`;
  return `${normalizedBase}${renderPattern(normalizedPattern, values)}`;
};

const appendQueryParams = (url, queryString) => {
  if (!queryString) return url;

  const parsed = new URL(url);
  const params = new URLSearchParams(String(queryString).replace(/^\?/, ''));
  for (const [key, value] of params.entries()) {
    if (!parsed.searchParams.has(key)) {
      parsed.searchParams.set(key, value);
    }
  }
  return parsed.toString();
};

const providerEnvKey = (id) => id.toUpperCase().replace(/[^A-Z0-9]/g, '_');
const forcedEnabledProviderIds = new Set(['env-11', 'env-12', 'env-13']);

const validateBaseUrl = (baseUrl) => {
  if (!baseUrl) return '';

  let parsed;
  try {
    parsed = new URL(baseUrl);
  } catch {
    return '';
  }

  if (parsed.protocol !== 'https:' || parsed.username || parsed.password) return '';
  parsed.hash = '';
  parsed.search = '';
  return parsed.toString().replace(/\/+$/, '');
};

const validatePattern = (pattern, fallback) => {
  const value = String(pattern || fallback || '').trim();
  if (!value || /^https?:\/\//i.test(value) || value.includes('..')) return fallback;
  return value.startsWith('/') ? value : `/${value}`;
};

const providerHealthScore = (id) => numberValue(
  envValue(`EMBED_PROVIDER_${providerEnvKey(id)}_HEALTH_SCORE`),
  100
);

const providerEnabled = (id, index) => boolValue(
  forcedEnabledProviderIds.has(id)
    ? 'true'
    : envValue(`EMBED_PROVIDER_${providerEnvKey(id)}_ENABLED`,
      index ? envValue(`AUTHORIZED_EMBED_PROVIDER_${index}_ENABLED`, 'true') : 'true'),
  true
);

const providerConfig = ({
  id,
  name,
  baseUrl,
  moviePattern,
  tvPattern,
  queryParams = '',
  index,
  enabled = true,
  healthScore = 100
}) => {
  const normalizedBaseUrl = validateBaseUrl(baseUrl);

  return {
    id,
    name,
    baseUrl: normalizedBaseUrl,
    moviePattern: validatePattern(moviePattern, '/movie/{tmdb_id}'),
    tvPattern: validatePattern(tvPattern, '/tv/{tmdb_id}/{season}/{episode}'),
    queryParams,
    enabled: Boolean(normalizedBaseUrl) && enabled && providerEnabled(id, index),
    healthScore: providerHealthScore(id) || healthScore,
    index
  };
};

const defaultProviders = [
  providerConfig({
    id: 'custom',
    name: envValue('CUSTOM_EMBED_NAME', 'Custom'),
    baseUrl: envValue('CUSTOM_EMBED_BASE_URL'),
    moviePattern: envValue('CUSTOM_EMBED_MOVIE_PATTERN', '/movie/{tmdb_id}'),
    tvPattern: envValue('CUSTOM_EMBED_TV_PATTERN', '/tv/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-1',
    index: 1,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_1_NAME', '2Embed'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_1_BASE_URL', 'https://2embed.to'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_1_MOVIE_PATTERN', '/embed/tmdb/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_1_TV_PATTERN', '/embed/tmdb/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-2',
    index: 2,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_2_NAME', 'VidLink'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_2_BASE_URL', 'https://vidlink.pro'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_2_MOVIE_PATTERN', '/movie/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_2_TV_PATTERN', '/tv/{tmdb_id}/{season}/{episode}'),
    queryParams: envValue(
      'AUTHORIZED_EMBED_PROVIDER_2_QUERY_PARAMS',
      'autoplay=false&player=default&title=true&poster=true'
    )
  }),
  providerConfig({
    id: 'env-3',
    index: 3,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_3_NAME', 'VidSrcMe.su'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_3_BASE_URL', 'https://vidsrc.me'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_3_MOVIE_PATTERN', '/embed/tmdb/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_3_TV_PATTERN', '/embed/tmdb/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-4',
    index: 4,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_4_NAME', 'VSEmbed.ru'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_4_BASE_URL', 'https://vsemembed.ru'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_4_MOVIE_PATTERN', '/embed/tmdb/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_4_TV_PATTERN', '/embed/tmdb/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-5',
    index: 5,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_5_NAME', 'VidSrc-Embed.ru'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_5_BASE_URL', 'https://vidsrc-embed.ru'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_5_MOVIE_PATTERN', '/embed/tmdb/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_5_TV_PATTERN', '/embed/tmdb/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-6',
    index: 6,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_6_NAME', 'VidSrc-Embed.su'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_6_BASE_URL', 'https://vidsrc-embed.su'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_6_MOVIE_PATTERN', '/embed/tmdb/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_6_TV_PATTERN', '/embed/tmdb/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-7',
    index: 7,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_7_NAME', 'vsrc.su'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_7_BASE_URL', 'https://vsrc.su'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_7_MOVIE_PATTERN', '/embed/tmdb/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_7_TV_PATTERN', '/embed/tmdb/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-8',
    index: 8,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_8_NAME', 'NontonGo'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_8_BASE_URL', 'https://nontongo.com'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_8_MOVIE_PATTERN', '/embed/tmdb/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_8_TV_PATTERN', '/embed/tmdb/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-9',
    index: 9,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_9_NAME', 'VidSrc.cc'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_9_BASE_URL', 'https://vidsrc.cc/v2'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_9_MOVIE_PATTERN', '/embed/movie/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_9_TV_PATTERN', '/embed/tv/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-10',
    index: 10,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_10_NAME', 'VidSrc.cc v3'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_10_BASE_URL', 'https://vidsrc.cc/v3'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_10_MOVIE_PATTERN', '/embed/movie/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_10_TV_PATTERN', '/embed/tv/{tmdb_id}/{season}/{episode}')
  }),
  providerConfig({
    id: 'env-11',
    index: 11,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_11_NAME', 'FileMoon'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_11_BASE_URL', 'https://filemoon.sx'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_11_MOVIE_PATTERN', '/e/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_11_TV_PATTERN', '/e/{tmdb_id}-{season}-{episode}')
  }),
  providerConfig({
    id: 'env-12',
    index: 12,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_12_NAME', 'Streamtape'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_12_BASE_URL', 'https://streamtape.com'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_12_MOVIE_PATTERN', '/e/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_12_TV_PATTERN', '/e/{tmdb_id}-{season}-{episode}')
  }),
  providerConfig({
    id: 'env-13',
    index: 13,
    name: envValue('AUTHORIZED_EMBED_PROVIDER_13_NAME', 'VOE'),
    baseUrl: envValue('AUTHORIZED_EMBED_PROVIDER_13_BASE_URL', 'https://voe.sx'),
    moviePattern: envValue('AUTHORIZED_EMBED_PROVIDER_13_MOVIE_PATTERN', '/e/{tmdb_id}'),
    tvPattern: envValue('AUTHORIZED_EMBED_PROVIDER_13_TV_PATTERN', '/e/{tmdb_id}-{season}-{episode}')
  })
];

const blacklistedValues = () => new Set(
  splitList(process.env.EMBED_PROVIDER_BLACKLIST || '')
    .map((item) => item.toLowerCase())
);

const isBlacklisted = (provider) => {
  const blacklist = blacklistedValues();
  return blacklist.has(provider.id.toLowerCase()) || blacklist.has(provider.name.toLowerCase());
};

const embedProviders = defaultProviders;

const providerById = (providerId) => embedProviders.find((provider) => provider.id === providerId);

const providerAllowlist = () => splitList(process.env.EMBED_PROVIDERS);

const orderedByAllowlist = (providers) => {
  const allowlist = providerAllowlist();
  if (allowlist.length === 0) return providers;

  const byId = new Map(providers.map((provider) => [provider.id, provider]));
  return allowlist.map((id) => byId.get(id)).filter(Boolean);
};

const enabledEmbedProviders = () => orderedByAllowlist(embedProviders)
  .filter((provider) => provider.enabled)
  .filter((provider) => provider.baseUrl)
  .filter((provider) => !isBlacklisted(provider))
  .sort((a, b) => b.healthScore - a.healthScore);

const fallbackProviders = (preferredProviderId) => {
  const enabled = enabledEmbedProviders();
  if (!preferredProviderId) return enabled;

  return [
    ...enabled.filter((provider) => provider.id === preferredProviderId),
    ...enabled.filter((provider) => provider.id !== preferredProviderId)
  ];
};

const randomProvider = (providers = enabledEmbedProviders()) => {
  if (providers.length === 0) return null;
  return providers[Math.floor(Math.random() * providers.length)];
};

const chooseEmbedProvider = ({ providerId, strategy = process.env.EMBED_PROVIDER_SELECTION || 'random' } = {}) => {
  const candidates = fallbackProviders(providerId);
  if (candidates.length === 0) return null;
  if (providerId && candidates[0]?.id === providerId) return candidates[0];
  if (strategy === 'best-health') return candidates[0];
  return randomProvider(candidates);
};

const buildMovieEmbedUrl = (provider, tmdbId) => appendQueryParams(
  joinEmbedUrl(provider.baseUrl, provider.moviePattern, {
    tmdb_id: tmdbId
  }),
  provider.queryParams
);

const buildTvEmbedUrl = (provider, tmdbId, season, episode) => appendQueryParams(
  joinEmbedUrl(provider.baseUrl, provider.tvPattern, {
    tmdb_id: tmdbId,
    season,
    episode
  }),
  provider.queryParams
);

module.exports = {
  embedProviders,
  enabledEmbedProviders,
  fallbackProviders,
  chooseEmbedProvider,
  randomProvider,
  providerById,
  buildMovieEmbedUrl,
  buildTvEmbedUrl
};
