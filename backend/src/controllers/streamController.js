const { streamService } = require('../services/streamService');

const streamController = {
  providers: (req, res) => {
    res.json({ providers: streamService.providers() });
  },
  movie: async (req, res) => {
    res.json(await streamService.movie(req.params.tmdbId, req.query.provider));
  },
  tv: async (req, res) => {
    res.json(await streamService.tv(req.params.tmdbId, req.params.season, req.params.episode, req.query.provider));
  }
};

module.exports = { streamController };
