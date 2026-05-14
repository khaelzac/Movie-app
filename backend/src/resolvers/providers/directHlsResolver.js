const { fetchText } = require('../utils/browserFetch');
const { extractHlsCandidates } = require('../utils/extractionStrategies');
const { validateHlsPlaylist, validateHlsUrl } = require('../utils/hlsValidator');

const refererFor = (url) => {
  try {
    return new URL(url).origin;
  } catch (_error) {
    return '';
  }
};

const directHlsResolver = {
  name: 'direct-hls',
  resolve: async ({ embedUrl }, options = {}) => {
    const referer = refererFor(embedUrl);

    if (validateMaybeHlsUrl(embedUrl)) {
      return {
        streamUrl: await validateHlsPlaylist(embedUrl, {
          timeoutMs: options.timeoutMs,
          referer,
          retries: options.retries
        }),
        referer,
        subtitles: []
      };
    }

    const payload = await fetchText(embedUrl, {
      timeoutMs: options.timeoutMs,
      referer,
      retries: options.retries,
      accept: 'application/json,text/plain,application/vnd.apple.mpegurl,*/*;q=0.8',
      destination: 'empty',
      mode: 'cors'
    });

    const candidates = extractHlsCandidates(payload, embedUrl);
    for (const candidate of candidates) {
      try {
        return {
          streamUrl: await validateHlsPlaylist(candidate.url, {
            timeoutMs: options.timeoutMs,
            referer,
            retries: options.retries
          }),
          referer,
          subtitles: []
        };
      } catch (_error) {
        // Keep looking; direct API payloads sometimes include expired backups.
      }
    }

    const error = new Error('No HLS stream URL found in direct provider response.');
    error.status = 502;
    throw error;
  }
};

const validateMaybeHlsUrl = (value) => {
  try {
    validateHlsUrl(value);
    return true;
  } catch (_error) {
    return false;
  }
};

module.exports = { directHlsResolver };
