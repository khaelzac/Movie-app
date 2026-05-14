const { fetchText } = require('./browserFetch');

const isHlsUrl = (value) => {
  try {
    return new URL(value).pathname.toLowerCase().endsWith('.m3u8');
  } catch (_error) {
    return false;
  }
};

const hlsError = (message) => {
  const error = new Error(message);
  error.status = 502;
  return error;
};

const validateHlsUrl = (value) => {
  let parsed;
  try {
    parsed = new URL(value);
  } catch (_error) {
    throw hlsError('Resolved stream URL is not a valid URL.');
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw hlsError('Resolved stream URL must use HTTP or HTTPS.');
  }

  if (!isHlsUrl(parsed.toString())) {
    throw hlsError('Resolved stream URL is not an HLS .m3u8 playlist.');
  }

  return parsed.toString();
};

const validateHlsPlaylist = async (value, options = {}) => {
  const url = validateHlsUrl(value);
  const playlist = await fetchText(url, {
    timeoutMs: options.timeoutMs,
    referer: options.referer,
    retries: options.retries ?? 1,
    retryDelayMs: options.retryDelayMs,
    accept: 'application/vnd.apple.mpegurl,application/x-mpegURL,text/plain,*/*;q=0.8',
    destination: 'empty',
    mode: 'cors',
    headers: {
      Range: 'bytes=0-65535',
      ...(options.headers || {})
    },
    validateStatus: (status) => status >= 200 && status < 400
  });

  if (!String(playlist).includes('#EXTM3U')) {
    throw hlsError('Resolved stream URL did not return a valid #EXTM3U playlist.');
  }

  return url;
};

module.exports = { isHlsUrl, validateHlsPlaylist, validateHlsUrl };
