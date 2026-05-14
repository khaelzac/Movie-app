const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { env } = require('./config/env');
const apiRoutes = require('./routes');
const { rateLimiter } = require('./middleware/rateLimiter');
const { noStore } = require('./middleware/cacheHeaders');
const { notFoundHandler, errorHandler } = require('./middleware/errorHandler');

const app = express();

app.set('trust proxy', 1);
app.disable('x-powered-by');
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  hsts: env.isProduction ? { maxAge: 15552000, includeSubDomains: true, preload: true } : false
}));
app.use(cors({ origin: env.allowedOrigins, credentials: false }));
app.use(express.json({ limit: '64kb' }));
if (!env.isProduction) {
  app.use(require('morgan')('dev'));
}
app.use(rateLimiter);

app.get('/health', noStore, (_req, res) => {
  res.json({ ok: true, service: 'ocampoflix-backend' });
});

app.use('/api', apiRoutes);
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
