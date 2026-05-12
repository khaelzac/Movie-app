const { streamService } = require('../services/streamService');

const streamController = {
  movie: (req, res) => {
    res.json(streamService.movie(req.params.tmdbId));
  },
  tv: (req, res) => {
    res.json(streamService.tv(req.params.tmdbId, req.params.season, req.params.episode));
  }
};

module.exports = { streamController };
