const { env } = require('../config/env');
const { joinUrl, positiveInt } = require('./providerUtils');

const vidsrcProvider = {
  name: 'vidsrc',
  label: 'VidSrc',
  isConfigured: () => Boolean(env.vidsrcBaseUrl),
  movie: (tmdbId) => ({
    provider: 'vidsrc',
    mediaType: 'movie',
    tmdbId: positiveInt(tmdbId, 'tmdbId'),
    url: joinUrl(env.vidsrcBaseUrl, 'movie', tmdbId)
  }),
  tv: (tmdbId, season, episode) => ({
    provider: 'vidsrc',
    mediaType: 'tv',
    tmdbId: positiveInt(tmdbId, 'tmdbId'),
    season: positiveInt(season, 'season'),
    episode: positiveInt(episode, 'episode'),
    url: joinUrl(env.vidsrcBaseUrl, 'tv', tmdbId, season, episode)
  })
};

module.exports = { vidsrcProvider };
