const express = require('express');
const { streamController } = require('../controllers/streamController');
const { asyncHandler } = require('../utils/asyncHandler');
const { noStore } = require('../middleware/cacheHeaders');

const router = express.Router();

router.get('/stream/movie/:tmdbId', noStore, asyncHandler(streamController.movie));
router.get('/stream/tv/:tmdbId/:season/:episode', noStore, asyncHandler(streamController.tv));

module.exports = router;
