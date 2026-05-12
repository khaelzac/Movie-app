const rateLimit = require('express-rate-limit');
const { env } = require('../config/env');

const rateLimiter = rateLimit({
  windowMs: env.rateLimitWindowMs,
  max: env.rateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: {
      message: 'Too many requests. Please slow down.',
      status: 429
    }
  }
});

module.exports = { rateLimiter };
