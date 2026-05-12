const { env } = require('../config/env');
const { joinUrl, positiveInt } = require('./providerUtils');

const videasyProvider = {
  name: 'videasy',
  movie: (tmdbId) => ({
    provider: 'videasy',
    mediaType: 'movie',
    tmdbId: positiveInt(tmdbId, 'tmdbId'),
    url: joinUrl(env.videasyBaseUrl, 'movie', tmdbId)
  }),
  tv: (tmdbId, season, episode) => ({
    provider: 'videasy',
    mediaType: 'tv',
    tmdbId: positiveInt(tmdbId, 'tmdbId'),
    season: positiveInt(season, 'season'),
    episode: positiveInt(episode, 'episode'),
    url: joinUrl(env.videasyBaseUrl, 'tv', tmdbId, season, episode)
  })
};

module.exports = { videasyProvider };
