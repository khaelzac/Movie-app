const { env } = require('../config/env');
const { videasyProvider } = require('../providers/videasyProvider');
const { vidsrcProvider } = require('../providers/vidsrcProvider');

const providers = {
  videasy: videasyProvider,
  vidsrc: vidsrcProvider
};

const activeProvider = () => {
  const provider = providers[env.streamProvider];
  if (!provider) {
    const error = new Error('Playback provider is disabled or unsupported.');
    error.status = 501;
    throw error;
  }
  return provider;
};

const streamService = {
  movie: (tmdbId) => activeProvider().movie(tmdbId),
  tv: (tmdbId, season, episode) => activeProvider().tv(tmdbId, season, episode)
};

module.exports = { streamService };
