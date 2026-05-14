const { crawlForHls } = require('../utils/iframeCrawler');
const { validateHlsPlaylist } = require('../utils/hlsValidator');

const createProviderResolver = ({
  name,
  maxPages,
  resolveBeforeCrawl
}) => ({
  name,
  resolve: async ({ embedUrl, provider, source }, options = {}) => {
    const direct = resolveBeforeCrawl
      ? await resolveBeforeCrawl({ embedUrl, provider, source }, options)
      : null;

    const resolved = direct || await crawlForHls(embedUrl, {
      timeoutMs: options.timeoutMs,
      referer: options.referer || embedUrl,
      retries: options.retries,
      maxPages
    });

    if (!resolved?.streamUrl) {
      const error = new Error(`No HLS stream URL found for ${name}.`);
      error.status = 502;
      throw error;
    }

    const referer = resolved.referer || new URL(embedUrl).origin;

    return {
      streamUrl: resolved.validated
        ? resolved.streamUrl
        : await validateHlsPlaylist(resolved.streamUrl, {
          timeoutMs: options.timeoutMs,
          referer,
          retries: options.retries
        }),
      referer,
      subtitles: Array.isArray(resolved.subtitles) ? resolved.subtitles : []
    };
  }
});

module.exports = { createProviderResolver };
