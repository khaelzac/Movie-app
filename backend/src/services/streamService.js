const { env } = require('../config/env');
const { createCustomEmbedProvider, customEmbedProvider } = require('../providers/customEmbedProvider');
const { videasyProvider } = require('../providers/videasyProvider');
const { vidsrcProvider } = require('../providers/vidsrcProvider');

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

const configuredProviders = () => providerOrder()
  .map((name) => providers[name])
  .filter((provider) => provider && provider.isConfigured());

const activeProvider = (providerName) => {
  const enabled = configuredProviders();
  const provider = providerName
    ? enabled.find((item) => item.name === providerName)
    : enabled[0];
  if (!provider) {
    const error = new Error(providerName
      ? `Playback provider "${providerName}" is disabled or unsupported.`
      : 'Playback provider is disabled or unsupported.');
    error.status = 501;
    throw error;
  }
  return provider;
};

const streamService = {
  providers: () => configuredProviders().map((provider) => ({
    id: provider.name,
    name: provider.label || provider.name
  })),
  movie: (tmdbId, providerName) => activeProvider(providerName).movie(tmdbId),
  tv: (tmdbId, season, episode, providerName) => activeProvider(providerName).tv(tmdbId, season, episode)
};

module.exports = { streamService };
