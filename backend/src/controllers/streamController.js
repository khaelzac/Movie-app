const { streamService } = require('../services/streamService');

const streamController = {
  providers: (req, res) => {
    res.json({ providers: streamService.providers() });
  },
  movie: (req, res) => {
    res.json(streamService.movie(req.params.tmdbId, req.query.provider));
  },
  tv: (req, res) => {
    res.json(streamService.tv(req.params.tmdbId, req.params.season, req.params.episode, req.query.provider));
  }
};

module.exports = { streamController };
