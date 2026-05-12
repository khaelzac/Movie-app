const express = require('express');
const { catalogController } = require('../controllers/catalogController');
const { asyncHandler } = require('../utils/asyncHandler');
const { withPagination } = require('../middleware/validate');
const { cacheHeaders } = require('../middleware/cacheHeaders');

const router = express.Router();

router.get('/trending', cacheHeaders(300), withPagination, asyncHandler(catalogController.trending));
router.get('/movies/popular', cacheHeaders(), withPagination, asyncHandler(catalogController.popularMovies));
router.get('/tv/popular', cacheHeaders(), withPagination, asyncHandler(catalogController.popularTv));
router.get('/top-rated', cacheHeaders(), withPagination, asyncHandler(catalogController.topRated));
router.get('/movie/:id', cacheHeaders(1800), asyncHandler(catalogController.movieDetails));
router.get('/tv/:id', cacheHeaders(1800), asyncHandler(catalogController.tvDetails));
router.get('/tv/:id/season/:season', cacheHeaders(1800), asyncHandler(catalogController.tvSeasonDetails));
router.get('/search', cacheHeaders(300), withPagination, asyncHandler(catalogController.search));
router.get('/genres', cacheHeaders(86400), asyncHandler(catalogController.genres));
router.get('/recommendations/:id', cacheHeaders(), withPagination, asyncHandler(catalogController.recommendations));
router.get('/similar/:id', cacheHeaders(), withPagination, asyncHandler(catalogController.similar));
router.get('/genres/:slug', cacheHeaders(), withPagination, asyncHandler(catalogController.genreRail));

module.exports = router;
