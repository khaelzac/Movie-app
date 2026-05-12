const { tmdbService } = require('../services/tmdbService');
const { formatDetails, formatGenres, formatList, formatSeason } = require('../utils/responseFormatter');
const { numericId, positiveInt, validMediaType } = require('../middleware/validate');

const page = (req) => positiveInt(req.query.page, 1, 500);

const catalogController = {
  trending: async (req, res) => {
    const mediaType = validMediaType(req.query.mediaType || 'all', 'all', true);
    const timeWindow = req.query.timeWindow || 'week';
    const data = await tmdbService.trending(mediaType, timeWindow, page(req));
    res.json(formatList(data, mediaType === 'all' ? 'movie' : mediaType));
  },
  popularMovies: async (req, res) => {
    res.json(formatList(await tmdbService.popularMovies(page(req)), 'movie'));
  },
  popularTv: async (req, res) => {
    res.json(formatList(await tmdbService.popularTv(page(req)), 'tv'));
  },
  topRated: async (req, res) => {
    const mediaType = validMediaType(req.query.mediaType, 'movie');
    res.json(formatList(await tmdbService.topRated(mediaType, page(req)), mediaType));
  },
  movieDetails: async (req, res) => {
    res.json(formatDetails(await tmdbService.movieDetails(numericId(req.params.id)), 'movie'));
  },
  tvDetails: async (req, res) => {
    res.json(formatDetails(await tmdbService.tvDetails(numericId(req.params.id)), 'tv'));
  },
  tvSeasonDetails: async (req, res) => {
    res.json(formatSeason(await tmdbService.tvSeasonDetails(numericId(req.params.id), numericId(req.params.season, 'season'))));
  },
  genres: async (req, res) => {
    const mediaType = validMediaType(req.query.mediaType, 'movie');
    res.json(formatGenres(await tmdbService.genres(mediaType)));
  },
  search: async (req, res) => {
    const query = String(req.query.query || '').trim();
    if (query.length < 2) {
      const error = new Error('Search query must be at least 2 characters.');
      error.status = 400;
      throw error;
    }
    return res.json(formatList(await tmdbService.search(query, page(req)), 'movie'));
  },
  recommendations: async (req, res) => {
    const mediaType = validMediaType(req.query.mediaType, 'movie');
    res.json(formatList(await tmdbService.recommendations(mediaType, numericId(req.params.id), page(req)), mediaType));
  },
  similar: async (req, res) => {
    const mediaType = validMediaType(req.query.mediaType, 'movie');
    res.json(formatList(await tmdbService.similar(mediaType, numericId(req.params.id), page(req)), mediaType));
  },
  genreRail: async (req, res) => {
    const mediaType = validMediaType(req.query.mediaType, 'movie');
    res.json(formatList(await tmdbService.byGenreSlug(req.params.slug, mediaType, page(req)), mediaType));
  }
};

module.exports = { catalogController };
