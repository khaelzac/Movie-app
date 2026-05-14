const { embedService } = require('../services/embedService');

const embedController = {
  providers: (_req, res) => {
    res.json({
      success: true,
      providers: embedService.providers()
    });
  },

  movie: (req, res) => {
    res.json(embedService.movie(req.params.tmdbId, req.query.provider));
  },

  tv: (req, res) => {
    res.json(embedService.tv(
      req.params.tmdbId,
      req.params.season,
      req.params.episode,
      req.query.provider
    ));
  }
};

module.exports = { embedController };
