const notFoundHandler = (req, res) => {
  res.status(404).json({
    error: {
      message: 'Route not found',
      path: req.originalUrl,
      status: 404
    }
  });
};

const errorHandler = (err, req, res, _next) => {
  const status = err.status || err.response?.status || 500;
  const message = err.response?.data?.status_message || err.message || 'Unexpected server error';

  if (status === 502 && req.originalUrl.startsWith('/api/stream/')) {
    console.warn('[stream-resolver]', {
      path: req.originalUrl,
      message,
      cause: err.cause?.message,
      upstreamStatus: err.cause?.response?.status
    });
  } else if (status >= 500) {
    console.error(err);
  }

  res.status(status).json({ error: { message, status } });
};

module.exports = { notFoundHandler, errorHandler };
