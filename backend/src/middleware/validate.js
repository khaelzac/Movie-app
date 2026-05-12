const positiveInt = (value, fallback = 1, max = 500) => {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed < 1) return fallback;
  return Math.min(parsed, max);
};

const withPagination = (req, _res, next) => {
  req.query.page = positiveInt(req.query.page, 1, 500);
  next();
};

const validMediaType = (value, fallback = 'movie', allowAll = false) => {
  const allowed = allowAll ? ['all', 'movie', 'tv'] : ['movie', 'tv'];
  if (allowed.includes(value)) return value;
  return fallback;
};

const numericId = (value, name = 'id') => {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    const error = new Error(`${name} must be a positive number.`);
    error.status = 400;
    throw error;
  }
  return parsed;
};

module.exports = { numericId, positiveInt, validMediaType, withPagination };
