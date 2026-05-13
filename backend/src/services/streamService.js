const { env } = require('../config/env');
const { createCustomEmbedProvider, customEmbedProvider } = require('../providers/customEmbedProvider');
const { videasyProvider } = require('../providers/videasyProvider');
const { vidsrcProvider } = require('../providers/vidsrcProvider');
const { genericResolver } = require('../resolvers/genericResolver');
const { nontongoResolver } = require('../resolvers/nontongoResolver');
const { vidsrcResolver } = require('../resolvers/vidsrcResolver');

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

const resolverByProvider = {
  vidsrc: vidsrcResolver,
  'env-3': vidsrcResolver,
  'env-5': vidsrcResolver,
  'env-6': vidsrcResolver,
  'env-7': vidsrcResolver,
  'env-8': nontongoResolver,
  'env-9': vidsrcResolver
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

const isHlsUrl = (value) => {
  try {
    return new URL(value).pathname.toLowerCase().endsWith('.m3u8');
  } catch (_error) {
    return false;
  }
};

const validateStreamUrl = (value) => {
  let parsed;
  try {
    parsed = new URL(value);
  } catch (_error) {
    const error = new Error('Resolved stream URL is not a valid URL.');
    error.status = 502;
    throw error;
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    const error = new Error('Resolved stream URL must use HTTP or HTTPS.');
    error.status = 502;
    throw error;
  }

  if (!isHlsUrl(parsed.toString())) {
    const error = new Error('Resolved stream URL is not an HLS .m3u8 playlist.');
    error.status = 502;
    throw error;
  }

  return parsed.toString();
};

const withProxy = (streamUrl, referer) => {
  if (!env.streamProxyBaseUrl) return streamUrl;

  const proxyUrl = new URL(env.streamProxyBaseUrl);
  proxyUrl.searchParams.set('url', streamUrl);
  if (referer) proxyUrl.searchParams.set('referer', referer);
  return proxyUrl.toString();
};

const delay = (ms) => new Promise((resolve) => {
  setTimeout(resolve, ms);
});

const resolveWithRetry = async (provider, source) => {
  const resolver = resolverByProvider[provider.name] || genericResolver;
  let lastError;

  for (let attempt = 0; attempt <= env.streamResolveRetries; attempt += 1) {
    try {
      return await resolver.resolve({
        embedUrl: source.url,
        provider,
        source
      }, {
        timeoutMs: env.requestTimeoutMs
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
      const resolved = await resolveWithRetry(provider, source);
      const directStreamUrl = validateStreamUrl(resolved.streamUrl);
      const referer = resolved.referer || new URL(source.url).origin;

      return {
        provider: provider.name,
        streamUrl: withProxy(directStreamUrl, referer),
        referer,
        subtitles: Array.isArray(resolved.subtitles) ? resolved.subtitles : []
      };
    } catch (error) {
      failures.push(`${provider.name}: ${error.message}`);
      if (providerName) throw error;
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
