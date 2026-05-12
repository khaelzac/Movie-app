const notFoundHandler = (req, res) => {
  res.status(404).json({
    error: {
      message: 'Route not found',
      path: req.originalUrl,
      status: 404
    }
  });
};

const errorHandler = (err, _req, res, _next) => {
  const status = err.status || err.response?.status || 500;
  const message = err.response?.data?.status_message || err.message || 'Unexpected server error';

  if (status >= 500) {
    console.error(err);
  }

  res.status(status).json({ error: { message, status } });
};

module.exports = { notFoundHandler, errorHandler };
