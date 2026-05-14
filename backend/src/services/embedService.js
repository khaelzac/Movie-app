const crypto = require('crypto');
const { env } = require('../config/env');
const {
  embedProviders,
  buildMovieEmbedUrl,
  buildTvEmbedUrl,
  chooseEmbedProvider,
  enabledEmbedProviders
} = require('../config/embedProviders');

const positiveInt = (value, name) => {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    const error = new Error(`${name} must be a positive number.`);
    error.status = 400;
    throw error;
  }
  return parsed;
};

const base64Url = (value) => Buffer
  .from(value)
  .toString('base64')
  .replace(/\+/g, '-')
  .replace(/\//g, '_')
  .replace(/=+$/g, '');

const sign = (payload) => base64Url(
  crypto.createHmac('sha256', env.embedGatewaySecret).update(payload).digest()
);

const signedWorkerUrl = (payload) => {
  if (!env.embedGatewayBaseUrl) {
    const error = new Error('EMBED_GATEWAY_BASE_URL is required to generate playback URLs.');
    error.status = 501;
    throw error;
  }

  const token = base64Url(JSON.stringify(payload));
  const signature = sign(token);
  const url = new URL(env.embedGatewayBaseUrl);

  url.pathname = `${url.pathname.replace(/\/+$/g, '')}/embed`.replace(/\/{2,}/g, '/');
  url.searchParams.set('token', token);
  url.searchParams.set('signature', signature);

  return url.toString();
};

const chooseProvider = (providerId) => {
  const selectedProvider = chooseEmbedProvider({
    providerId: providerId || env.embedProvider || undefined
  });

  if (!selectedProvider) {
    const error = new Error(providerId
      ? `Embed provider "${providerId}" is disabled or unsupported.`
      : 'No configured embed providers are available.');
    error.status = 501;
    throw error;
  }

  return selectedProvider;
};

const createResponse = ({ provider, providerEmbedUrl, mediaType, tmdbId, season, episode }) => {
  const expiresAt = Math.floor(Date.now() / 1000) + env.embedTokenTtlSeconds;
  const embedUrl = signedWorkerUrl({
    provider: provider.id,
    providerName: provider.name,
    providerEmbedUrl,
    mediaType,
    tmdbId,
    season,
    episode,
    exp: expiresAt
  });

  return {
    success: true,
    provider: provider.name,
    embedUrl
  };
};

const embedService = {
  providers: () => {
    const availableProviderIds = new Set(
      enabledEmbedProviders().map((provider) => provider.id)
    );

    return embedProviders.map((provider) => ({
      id: provider.id,
      name: provider.name,
      configured: Boolean(provider.baseUrl),
      enabled: availableProviderIds.has(provider.id),
      healthScore: provider.healthScore
    }));
  },

  movie: (tmdbId, providerId) => {
    const id = positiveInt(tmdbId, 'tmdbId');
    const provider = chooseProvider(providerId);
    const providerEmbedUrl = buildMovieEmbedUrl(provider, id);

    return createResponse({
      provider,
      providerEmbedUrl,
      mediaType: 'movie',
      tmdbId: id
    });
  },

  tv: (tmdbId, season, episode, providerId) => {
    const id = positiveInt(tmdbId, 'tmdbId');
    const seasonNumber = positiveInt(season, 'season');
    const episodeNumber = positiveInt(episode, 'episode');
    const provider = chooseProvider(providerId);
    const providerEmbedUrl = buildTvEmbedUrl(provider, id, seasonNumber, episodeNumber);

    return createResponse({
      provider,
      providerEmbedUrl,
      mediaType: 'tv',
      tmdbId: id,
      season: seasonNumber,
      episode: episodeNumber
    });
  }
};

module.exports = { embedService };
