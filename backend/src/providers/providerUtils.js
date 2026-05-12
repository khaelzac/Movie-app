const joinUrl = (baseUrl, ...parts) => {
  if (!baseUrl) {
    const error = new Error('Playback provider is not configured.');
    error.status = 501;
    throw error;
  }

  const base = baseUrl.replace(/\/+$/, '');
  const path = parts.map((part) => encodeURIComponent(String(part))).join('/');
  return `${base}/${path}`;
};

const positiveInt = (value, name) => {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed) || parsed < 1) {
    const error = new Error(`${name} must be a positive number.`);
    error.status = 400;
    throw error;
  }
  return parsed;
};

module.exports = { joinUrl, positiveInt };
