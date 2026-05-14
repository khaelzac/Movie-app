const { env } = require('../config/env');
const { createCustomEmbedProvider, customEmbedProvider } = require('../providers/customEmbedProvider');
const { videasyProvider } = require('../providers/videasyProvider');
const { vidsrcProvider } = require('../providers/vidsrcProvider');
const resolvedStreamCache = require('../resolvers/utils/memoryCache');
const { validateHlsUrl } = require('../resolvers/utils/hlsValidator');
const { resolverForProvider } = require('../resolvers/providers');
const { createProxiedHlsUrl } = require('./streamProxyService');

const envProviders = Object.fromEntries(
  env.authorizedEmbedProviders.map((provider) => [
    provider.id,
    createCustomEmbedProvider(provider)
  ])
);

const providers = {
  custom: customEmbedProvider,
  videasy: videasyProvider,
  vidsrc: vidsrcProvider,
  ...envProviders
};

const providerOrder = () => {
  const requested = env.streamProviders.length > 0
    ? env.streamProviders
    : env.streamProvider && env.streamProvider !== 'disabled'
      ? [env.streamProvider]
      : Object.keys(providers);
  return requested.filter((name) => name !== 'disabled');
};

const orderedProviders = () => providerOrder()
  .map((name) => providers[name])
  .filter(Boolean);

const configuredProviders = () => providerOrder()
  .map((name) => providers[name])
  .filter((provider) => provider && provider.isConfigured());

const selectedProviders = (providerName) => {
  const enabled = configuredProviders();
  const selected = providerName
    ? enabled.filter((item) => item.name === providerName)
    : enabled;

  if (selected.length === 0) {
    const error = new Error(providerName
      ? `Playback provider "${providerName}" is disabled or unsupported.`
      : 'Playback provider is disabled or unsupported.');
    error.status = 501;
    throw error;
  }

  return selected;
};

const delay = (ms) => new Promise((resolve) => {
  setTimeout(resolve, ms);
});

const providerFailureMessage = (error) => {
  const status = error.response?.status || error.status;
  if (status === 403) return 'upstream rejected the request';
  if (status === 404) return 'upstream embed URL was not found';
  if (status === 429) return 'upstream rate limited the request';
  if (status) return `upstream returned ${status}`;

  if (error.code === 'ENOTFOUND') return 'DNS not found';
  if (error.code === 'ECONNABORTED') return 'request timed out';
  if (error.code === 'CERT_HAS_EXPIRED' || /certificate has expired/i.test(error.message)) {
    return 'certificate has expired';
  }
  if (/no hls stream url found/i.test(error.message)) return error.message;
  if (/not a valid url|not an hls|#extm3u/i.test(error.message)) return error.message;

  return error.message || 'provider failed';
};

const providerFailure = (provider, error) => {
  const wrapped = new Error(`${provider.name}: ${providerFailureMessage(error)}`);
  wrapped.status = 502;
  wrapped.cause = error;
  return wrapped;
};

const cacheKeyFor = (provider, source) => [
  'stream',
  provider.name,
  source.mediaType,
  source.tmdbId,
  source.season || '',
  source.episode || '',
  source.url
].join(':');

const resolveWithRetry = async (provider, source) => {
  const resolver = resolverForProvider(provider, source);
  let lastError;

  for (let attempt = 0; attempt <= env.streamResolveRetries; attempt += 1) {
    try {
      return await resolver.resolve({
        embedUrl: source.url,
        provider,
        source
      }, {
        timeoutMs: env.requestTimeoutMs,
        retries: 1
      });
    } catch (error) {
      lastError = error;
      if (attempt < env.streamResolveRetries) {
        await delay(200 * (attempt + 1));
      }
    }
  }

  throw lastError;
};

const resolveFromProviders = async (mediaFactory, providerName) => {
  const failures = [];

  for (const provider of selectedProviders(providerName)) {
    try {
      const source = mediaFactory(provider);
      const resolved = await resolvedStreamCache.getOrSet(
        cacheKeyFor(provider, source),
        () => resolveWithRetry(provider, source),
        env.cacheTtlSeconds
      );
      const directStreamUrl = validateHlsUrl(resolved.streamUrl);
      const referer = resolved.referer || new URL(source.url).origin;

      return {
        provider: provider.name,
        streamUrl: createProxiedHlsUrl(directStreamUrl, referer),
        referer,
        subtitles: Array.isArray(resolved.subtitles) ? resolved.subtitles : []
      };
    } catch (error) {
      const failure = providerFailure(provider, error);
      failures.push(failure.message);
      if (providerName) throw failure;
    }
  }

  const error = new Error(`No configured provider resolved a playable HLS stream. ${failures.join(' | ')}`);
  error.status = 502;
  throw error;
};

const streamService = {
  providers: () => orderedProviders().map((provider) => ({
    id: provider.name,
    name: provider.label || provider.name,
    configured: provider.isConfigured()
  })),
  movie: (tmdbId, providerName) => resolveFromProviders(
    (provider) => provider.movie(tmdbId),
    providerName
  ),
  tv: (tmdbId, season, episode, providerName) => resolveFromProviders(
    (provider) => provider.tv(tmdbId, season, episode),
    providerName
  )
};

module.exports = { streamService };
