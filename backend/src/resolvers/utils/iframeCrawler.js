const { fetchEmbedHtml, fetchScript, fetchText } = require('./browserFetch');
const { extractHlsCandidates } = require('./extractionStrategies');
const { validateHlsPlaylist } = require('./hlsValidator');
const { logResolverEvent } = require('./logger');
const {
  decodePayload,
  extractApiUrls,
  extractDocumentUrls,
  extractIframeUrls,
  extractInlineScripts,
  extractScriptUrls,
  extractSubtitles,
  uniqueSubtitles
} = require('./sourceExtractor');

const DEFAULT_MAX_PAGES = 8;
const DEFAULT_MAX_DEPTH = 4;

const shouldCrawlUrl = (url) => {
  try {
    const parsed = new URL(url);
    const pathname = parsed.pathname.toLowerCase();
    if (/\.(png|jpe?g|gif|webp|svg|css|woff2?|ttf|ico)$/i.test(pathname)) {
      return false;
    }
    return ['http:', 'https:'].includes(parsed.protocol);
  } catch (_error) {
    return false;
  }
};

const fetchExternalScripts = async (html, baseUrl, options = {}) => {
  const scriptUrls = extractScriptUrls(html, baseUrl, options.maxScripts);
  const responses = await Promise.allSettled(scriptUrls.map((scriptUrl) => fetchScript(scriptUrl, {
    timeoutMs: options.timeoutMs,
    referer: baseUrl,
    retries: options.retries
  })));

  responses.forEach((response, index) => {
    if (response.status === 'rejected') {
      logResolverEvent('warn', 'script_fetch_failed', {
        url: scriptUrls[index],
        reason: response.reason?.message
      });
    }
  });

  return responses
    .filter((response) => response.status === 'fulfilled')
    .map((response) => response.value);
};

const payloadFromHtml = async (html, baseUrl, options = {}) => decodePayload([
  html,
  ...extractInlineScripts(html),
  ...await fetchExternalScripts(html, baseUrl, options)
].join('\n'));

const crawlForHls = async (startUrl, options = {}) => {
  const visited = new Set();
  const queue = [{
    url: startUrl,
    referer: options.referer || startUrl,
    depth: 0
  }];
  const subtitles = [];
  const maxPages = options.maxPages || DEFAULT_MAX_PAGES;
  const maxDepth = options.maxDepth ?? DEFAULT_MAX_DEPTH;
  const candidateFailures = [];
  const pageFetchFailures = [];

  while (queue.length > 0 && visited.size < maxPages) {
    const current = queue.shift();
    const currentUrl = current?.url;
    if (!currentUrl || visited.has(currentUrl) || !shouldCrawlUrl(currentUrl)) continue;
    if (current.depth > maxDepth) continue;
    visited.add(currentUrl);

    let html;
    try {
      html = await fetchEmbedHtml(currentUrl, {
        timeoutMs: options.timeoutMs,
        referer: current.referer,
        retries: options.retries
      });
    } catch (error) {
      pageFetchFailures.push(error);
      logResolverEvent('warn', 'page_fetch_failed', {
        url: currentUrl,
        depth: current.depth,
        reason: error.message,
        status: error.response?.status
      });
      continue;
    }

    const payload = await payloadFromHtml(html, currentUrl, options);
    const candidates = extractHlsCandidates(payload, currentUrl);

    subtitles.push(...extractSubtitles(payload, currentUrl));

    for (const candidate of candidates) {
      try {
        const streamUrl = await validateHlsPlaylist(candidate.url, {
          timeoutMs: options.timeoutMs,
          referer: currentUrl,
          retries: options.retries
        });

        logResolverEvent('info', 'hls_candidate_validated', {
          page: currentUrl,
          strategy: candidate.strategy,
          depth: current.depth
        });

        return {
          streamUrl,
          validated: true,
          referer: new URL(currentUrl).origin,
          subtitles: uniqueSubtitles(subtitles)
        };
      } catch (error) {
        candidateFailures.push(`${candidate.strategy}: ${error.message}`);
        logResolverEvent('warn', 'hls_candidate_rejected', {
          page: currentUrl,
          strategy: candidate.strategy,
          reason: error.message
        });
      }
    }

    const nextUrls = [
      ...extractIframeUrls(html, currentUrl),
      ...extractDocumentUrls(html, currentUrl),
      ...extractApiUrls(payload, currentUrl)
    ];

    for (const nextUrl of nextUrls) {
      if (!visited.has(nextUrl) && shouldCrawlUrl(nextUrl)) {
        queue.push({
          url: nextUrl,
          referer: currentUrl,
          depth: current.depth + 1
        });
      }
    }
  }

  if (candidateFailures.length > 0) {
    logResolverEvent('warn', 'hls_candidates_exhausted', {
      startUrl,
      checkedPages: visited.size,
      failures: candidateFailures.slice(0, 5)
    });
  } else {
    logResolverEvent('warn', 'hls_crawl_exhausted', {
      startUrl,
      checkedPages: visited.size,
      maxPages,
      maxDepth
    });
  }

  if (visited.size > 0 && pageFetchFailures.length === visited.size) {
    throw pageFetchFailures[0];
  }

  return null;
};

const resolveApiPayload = async (url, options = {}) => {
  const payload = await fetchText(url, {
    timeoutMs: options.timeoutMs,
    referer: options.referer,
    accept: 'application/json,text/plain,*/*;q=0.8',
    destination: 'empty',
    mode: 'cors'
  });

  const candidates = extractHlsCandidates(payload, url);

  for (const candidate of candidates) {
    try {
      const streamUrl = await validateHlsPlaylist(candidate.url, {
        timeoutMs: options.timeoutMs,
        referer: options.referer || url,
        retries: options.retries
      });

      return {
        streamUrl,
        validated: true,
        referer: options.referer ? new URL(options.referer).origin : new URL(url).origin,
        subtitles: uniqueSubtitles(extractSubtitles(payload, url))
      };
    } catch (error) {
      logResolverEvent('warn', 'api_hls_candidate_rejected', {
        url,
        strategy: candidate.strategy,
        reason: error.message
      });
    }
  }

  return null;
};

module.exports = {
  crawlForHls,
  payloadFromHtml,
  resolveApiPayload,
  shouldCrawlUrl
};
