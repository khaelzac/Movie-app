const express = require('express');
const { embedController } = require('../controllers/embedController');
const { asyncHandler } = require('../utils/asyncHandler');
const { noStore } = require('../middleware/cacheHeaders');

const router = express.Router();

router.get('/embed/providers', noStore, asyncHandler(embedController.providers));
router.get('/embed/movie/:tmdbId', noStore, asyncHandler(embedController.movie));
router.get('/embed/tv/:tmdbId/:season/:episode', noStore, asyncHandler(embedController.tv));

module.exports = router;
