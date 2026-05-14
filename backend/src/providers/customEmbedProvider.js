const { env } = require('../config/env');
const { positiveInt } = require('./providerUtils');

const encodeValue = (value) => encodeURIComponent(String(value));

const buildUrl = (baseUrl, pattern, values) => {
  if (!baseUrl) {
    const error = new Error('Custom playback provider is not configured.');
    error.status = 501;
    throw error;
  }

  const base = baseUrl.replace(/\/+$/, '');
  const path = pattern.startsWith('/') ? pattern : `/${pattern}`;
  const resolved = path.replace(/\{(tmdb_id|season|episode)\}/g, (_, key) => encodeValue(values[key]));
  return `${base}${resolved}`;
};

const customEmbedProvider = {
  name: 'custom',
  label: env.customEmbedName,
  isConfigured: () => Boolean(env.customEmbedBaseUrl),
  movie: (tmdbId) => ({
    provider: 'custom',
    mediaType: 'movie',
    tmdbId: positiveInt(tmdbId, 'tmdbId'),
    url: buildUrl(env.customEmbedBaseUrl, env.customEmbedMoviePattern, {
      tmdb_id: tmdbId
    })
  }),
  tv: (tmdbId, season, episode) => ({
    provider: 'custom',
    mediaType: 'tv',
    tmdbId: positiveInt(tmdbId, 'tmdbId'),
    season: positiveInt(season, 'season'),
    episode: positiveInt(episode, 'episode'),
    url: buildUrl(env.customEmbedBaseUrl, env.customEmbedTvPattern, {
      tmdb_id: tmdbId,
      season,
      episode
    })
  })
};

const createCustomEmbedProvider = ({ id, name, baseUrl, moviePattern, tvPattern, resolver }) => ({
  name: id,
  label: name,
  resolver,
  isConfigured: () => Boolean(baseUrl),
  movie: (tmdbId) => ({
    provider: id,
    mediaType: 'movie',
    tmdbId: positiveInt(tmdbId, 'tmdbId'),
    url: buildUrl(baseUrl, moviePattern, {
      tmdb_id: tmdbId
    })
  }),
  tv: (tmdbId, season, episode) => ({
    provider: id,
    mediaType: 'tv',
    tmdbId: positiveInt(tmdbId, 'tmdbId'),
    season: positiveInt(season, 'season'),
    episode: positiveInt(episode, 'episode'),
    url: buildUrl(baseUrl, tvPattern, {
      tmdb_id: tmdbId,
      season,
      episode
    })
  })
});

module.exports = { createCustomEmbedProvider, customEmbedProvider };
