const axios = require('axios');
const cheerio = require('cheerio');

const DEFAULT_USER_AGENT = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  'AppleWebKit/537.36 (KHTML, like Gecko)',
  'Chrome/124.0.0.0 Safari/537.36'
].join(' ');

const toAbsoluteUrl = (value, baseUrl) => {
  if (!value || typeof value !== 'string') return null;

  const trimmed = value.trim()
    .replace(/^['"]|['"]$/g, '')
    .replace(/\\\//g, '/')
    .replace(/&amp;/g, '&');

  try {
    return new URL(trimmed, baseUrl).toString();
  } catch (_error) {
    return null;
  }
};

const unique = (values) => [...new Set(values.filter(Boolean))];

const decodeScriptText = (value) => {
  if (!value) return '';

  const withoutSlashEscapes = String(value).replace(/\\\//g, '/');
  return withoutSlashEscapes.replace(/\\u([0-9a-fA-F]{4})/g, (_match, hex) => (
    String.fromCharCode(Number.parseInt(hex, 16))
  ));
};

const fetchText = async (url, { timeoutMs, referer, accept }) => {
  const response = await axios.get(url, {
    timeout: timeoutMs,
    maxRedirects: 5,
    responseType: 'text',
    headers: {
      Accept: accept || '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      Referer: referer || new URL(url).origin,
      'User-Agent': DEFAULT_USER_AGENT
    },
    validateStatus: (status) => status >= 200 && status < 400
  });

  return String(response.data || '');
};

const fetchEmbedHtml = (embedUrl, options = {}) => fetchText(embedUrl, {
  ...options,
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
});

const documentUrlsFrom = (html, baseUrl) => {
  const $ = cheerio.load(html);
  const urls = [];

  $('iframe[src], embed[src], source[src], video[src], a[href]').each((_index, element) => {
    const raw = $(element).attr('src') || $(element).attr('href');
    const url = toAbsoluteUrl(raw, baseUrl);
    if (url) urls.push(url);
  });

  $('[data-src], [data-url], [data-href], [data-file]').each((_index, element) => {
    for (const attr of ['data-src', 'data-url', 'data-href', 'data-file']) {
      const url = toAbsoluteUrl($(element).attr(attr), baseUrl);
      if (url) urls.push(url);
    }
  });

  return unique(urls);
};

const apiUrlsFromPayload = (payload, baseUrl) => {
  const urls = [];
  const patterns = [
    /fetch\(\s*["']([^"']+)["']/gi,
    /axios\.(?:get|post)\(\s*["']([^"']+)["']/gi,
    /(?:url|file|source|playlist|stream)\s*[:=]\s*["']([^"']+)["']/gi
  ];

  for (const pattern of patterns) {
    for (const match of payload.matchAll(pattern)) {
      const value = match[1];
      if (!value || value.includes('${') || value.includes('.concat(')) continue;
      const url = toAbsoluteUrl(value, baseUrl);
      if (url) urls.push(url);
    }
  }

  return unique(urls);
};

const scriptSourcesFrom = (html, baseUrl) => {
  const $ = cheerio.load(html);
  const sources = [];

  $('script[src]').each((_index, element) => {
    const sourceUrl = toAbsoluteUrl($(element).attr('src'), baseUrl);
    if (sourceUrl) sources.push(sourceUrl);
  });

  return unique(sources).slice(0, 8);
};

const fetchScriptPayloads = async (scriptUrls, { timeoutMs, referer } = {}) => {
  const responses = await Promise.allSettled(scriptUrls.map((scriptUrl) => fetchText(scriptUrl, {
    timeoutMs,
    referer,
    accept: 'application/javascript,text/javascript,*/*;q=0.8'
  })));

  return responses
    .filter((response) => response.status === 'fulfilled')
    .map((response) => response.value);
};

const extractScriptPayload = async (html, baseUrl, options = {}) => {
  const $ = cheerio.load(html);
  const scripts = [];

  $('script').each((_index, element) => {
    const text = $(element).html();
    if (text) scripts.push(text);
  });

  const externalScripts = await fetchScriptPayloads(scriptSourcesFrom(html, baseUrl), {
    timeoutMs: options.timeoutMs,
    referer: baseUrl
  });

  return decodeScriptText([
    html,
    ...scripts,
    ...externalScripts
  ].join('\n'));
};

const extractM3u8Urls = (payload, baseUrl) => {
  const matches = [];
  const patterns = [
    /https?:\/\/[^\s"'<>\\)]+?\.m3u8(?:\?[^\s"'<>\\)]*)?/gi,
    /\/\/[^\s"'<>\\)]+?\.m3u8(?:\?[^\s"'<>\\)]*)?/gi,
    /["']([^"']+?\.m3u8(?:\?[^"']*)?)["']/gi
  ];

  for (const pattern of patterns) {
    for (const match of payload.matchAll(pattern)) {
      const raw = match[1] || match[0];
      const url = raw.startsWith('//') ? `https:${raw}` : raw;
      matches.push(toAbsoluteUrl(url, baseUrl));
    }
  }

  return unique(matches);
};

const subtitleUrlPattern = /https?:\/\/[^\s"'<>\\)]+?\.(?:vtt|srt|ass)(?:\?[^\s"'<>\\)]*)?|\/\/[^\s"'<>\\)]+?\.(?:vtt|srt|ass)(?:\?[^\s"'<>\\)]*)?|["']([^"']+?\.(?:vtt|srt|ass)(?:\?[^"']*)?)["']/gi;

const subtitleMetadataNear = (payload, index) => {
  const window = payload.slice(Math.max(0, index - 250), Math.min(payload.length, index + 250));
  const label = window.match(/(?:label|name|title)\s*[:=]\s*["']([^"']{1,80})["']/i)?.[1];
  const language = window.match(/(?:lang|language|srclang)\s*[:=]\s*["']([^"']{1,20})["']/i)?.[1];
  const kind = window.match(/kind\s*[:=]\s*["']([^"']{1,30})["']/i)?.[1];

  return {
    label: label || language || 'Subtitle',
    language: language || null,
    kind: kind || 'subtitles'
  };
};

const extractSubtitles = (payload, baseUrl) => {
  const subtitles = [];
  const seen = new Set();

  for (const match of payload.matchAll(subtitleUrlPattern)) {
    const raw = match[1] || match[0];
    const url = toAbsoluteUrl(raw.startsWith('//') ? `https:${raw}` : raw, baseUrl);
    if (!url || seen.has(url)) continue;

    seen.add(url);
    subtitles.push({
      url,
      ...subtitleMetadataNear(payload, match.index || 0)
    });
  }

  return subtitles;
};

const createHtmlResolver = ({ name }) => ({
  name,
  resolve: async ({ embedUrl }, options = {}) => {
    const visited = new Set();
    const queue = [embedUrl];
    let subtitles = [];

    while (queue.length > 0 && visited.size < 8) {
      const currentUrl = queue.shift();
      if (!currentUrl || visited.has(currentUrl)) continue;
      visited.add(currentUrl);

      const html = await fetchEmbedHtml(currentUrl, {
        timeoutMs: options.timeoutMs,
        referer: options.referer || embedUrl
      });
      const payload = await extractScriptPayload(html, currentUrl, {
        timeoutMs: options.timeoutMs
      });
      const [streamUrl] = extractM3u8Urls(payload, currentUrl);
      subtitles = [
        ...subtitles,
        ...extractSubtitles(payload, currentUrl)
      ];

      if (streamUrl) {
        return {
          streamUrl,
          referer: new URL(currentUrl).origin,
          subtitles: uniqueSubtitles(subtitles)
        };
      }

      for (const nextUrl of [
        ...documentUrlsFrom(html, currentUrl),
        ...apiUrlsFromPayload(payload, currentUrl)
      ]) {
        if (!visited.has(nextUrl) && shouldCrawlUrl(nextUrl)) {
          queue.push(nextUrl);
        }
      }
    }

    const error = new Error(`No HLS stream URL found for ${name}.`);
    error.status = 502;
    throw error;
  }
});

const uniqueSubtitles = (subtitles) => {
  const seen = new Set();
  return subtitles.filter((subtitle) => {
    if (!subtitle.url || seen.has(subtitle.url)) return false;
    seen.add(subtitle.url);
    return true;
  });
};

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

module.exports = {
  createHtmlResolver,
  documentUrlsFrom,
  extractM3u8Urls,
  extractScriptPayload,
  extractSubtitles,
  fetchEmbedHtml,
  fetchText,
  toAbsoluteUrl
};
