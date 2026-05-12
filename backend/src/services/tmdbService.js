const axios = require('axios');
const { env } = require('../config/env');
const { getOrSet } = require('../utils/cache');

const tmdb = axios.create({
  baseURL: env.tmdbBaseUrl,
  timeout: env.requestTimeoutMs,
  decompress: true,
  params: {
    api_key: env.tmdbApiKey,
    language: 'en-US'
  },
  headers: {
    Accept: 'application/json',
    'Accept-Encoding': 'gzip, br'
  }
});

const request = async (path, params = {}, ttl) => {
  const key = `${path}:${JSON.stringify(params)}`;
  return getOrSet(key, async () => {
    const { data } = await tmdb.get(path, { params });
    return data;
  }, ttl);
};

const discoverByGenre = (mediaType, genreId, page) => request(`/discover/${mediaType}`, {
  page,
  with_genres: genreId,
  sort_by: 'popularity.desc',
  include_adult: false
});

const genreSlugs = {
  action: 28,
  adventure: 12,
  animation: 16,
  anime: 16,
  comedy: 35,
  crime: 80,
  documentary: 99,
  drama: 18,
  family: 10751,
  fantasy: 14,
  history: 36,
  horror: 27,
  music: 10402,
  mystery: 9648,
  romance: 10749,
  'science-fiction': 878,
  'sci-fi': 878,
  thriller: 53,
  war: 10752,
  western: 37
};

const tmdbService = {
  trending: (mediaType = 'all', timeWindow = 'week', page = 1) =>
    request(`/trending/${mediaType}/${timeWindow}`, { page }),
  popularMovies: (page = 1) => request('/movie/popular', { page }),
  popularTv: (page = 1) => request('/tv/popular', { page }),
  topRated: (mediaType = 'movie', page = 1) => request(`/${mediaType}/top_rated`, { page }),
  movieDetails: (id) => request(`/movie/${id}`, {
    append_to_response: 'images,credits,recommendations,similar,external_ids'
  }),
  tvDetails: (id) => request(`/tv/${id}`, {
    append_to_response: 'images,credits,recommendations,similar,external_ids'
  }),
  tvSeasonDetails: (id, seasonNumber) => request(`/tv/${id}/season/${seasonNumber}`),
  genres: (mediaType = 'movie') => request(`/genre/${mediaType}/list`),
  search: (query, page = 1) => request('/search/multi', {
    query,
    page,
    include_adult: false
  }),
  recommendations: (mediaType, id, page = 1) => request(`/${mediaType}/${id}/recommendations`, { page }),
  similar: (mediaType, id, page = 1) => request(`/${mediaType}/${id}/similar`, { page }),
  byGenreSlug: (slug, mediaType = 'movie', page = 1) => {
    const genreId = Number(slug) || genreSlugs[String(slug).toLowerCase()] || 28;
    return discoverByGenre(mediaType, genreId, page);
  }
};

module.exports = { tmdbService };
