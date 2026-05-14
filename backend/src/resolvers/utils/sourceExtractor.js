const cheerio = require('cheerio');

const unique = (values) => [...new Set(values.filter(Boolean))];

const toAbsoluteUrl = (value, baseUrl) => {
  if (!value || typeof value !== 'string') return null;

  const trimmed = value.trim()
    .replace(/^['"]|['"]$/g, '')
    .replace(/\\\//g, '/')
    .replace(/&amp;/g, '&');

  if (looksLikeDynamicScriptUrl(trimmed)) return null;

  try {
    return new URL(trimmed, baseUrl).toString();
  } catch (_error) {
    return null;
  }
};

const looksLikeDynamicScriptUrl = (value) => (
  /\$\{|[{}]|\b(?:encode|decode)URIComponent\s*\(|\.concat\s*\(/i.test(value) ||
  /(?:^|[^%])\+/.test(value)
);

const decodePayload = (value) => {
  if (!value) return '';

  return String(value)
    .replace(/\\\//g, '/')
    .replace(/\\u([0-9a-fA-F]{4})/g, (_match, hex) => (
      String.fromCharCode(Number.parseInt(hex, 16))
    ));
};

const extractIframeUrls = (html, baseUrl) => {
  const $ = cheerio.load(html);
  const urls = [];

  $('iframe[src], embed[src], frame[src]').each((_index, element) => {
    const url = toAbsoluteUrl($(element).attr('src'), baseUrl);
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

const extractDocumentUrls = (html, baseUrl) => {
  const $ = cheerio.load(html);
  const urls = [];

  $('source[src], video[src], a[href]').each((_index, element) => {
    const raw = $(element).attr('src') || $(element).attr('href');
    const url = toAbsoluteUrl(raw, baseUrl);
    if (url) urls.push(url);
  });

  return unique([
    ...extractIframeUrls(html, baseUrl),
    ...urls
  ]);
};

const extractInlineScripts = (html) => {
  const $ = cheerio.load(html);
  const scripts = [];

  $('script').each((_index, element) => {
    const text = $(element).html();
    if (text) scripts.push(text);
  });

  return scripts;
};

const extractScriptUrls = (html, baseUrl, maxScripts = 24) => {
  const $ = cheerio.load(html);
  const sources = [];

  $('script[src]').each((_index, element) => {
    const sourceUrl = toAbsoluteUrl($(element).attr('src'), baseUrl);
    if (sourceUrl) sources.push(sourceUrl);
  });

  return unique(sources).slice(0, maxScripts);
};

const extractApiUrls = (payload, baseUrl) => {
  const urls = [];
  const patterns = [
    /fetch\(\s*["']([^"']+)["']/gi,
    /axios\.(?:get|post)\(\s*["']([^"']+)["']/gi,
    /(?:url|file|source|playlist|stream|sources)\s*[:=]\s*["']([^"']+)["']/gi
  ];

  for (const pattern of patterns) {
    for (const match of payload.matchAll(pattern)) {
      const value = match[1];
      if (!value || looksLikeDynamicScriptUrl(value)) continue;
      const url = toAbsoluteUrl(value, baseUrl);
      if (url) urls.push(url);
    }
  }

  return unique(urls);
};

const extractHlsUrls = (payload, baseUrl) => {
  const { extractHlsUrls: extractWithStrategies } = require('./extractionStrategies');
  return extractWithStrategies(payload, baseUrl);
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
  const decoded = decodePayload(payload);
  const subtitles = [];
  const seen = new Set();

  for (const match of decoded.matchAll(subtitleUrlPattern)) {
    const raw = match[1] || match[0];
    const url = toAbsoluteUrl(raw.startsWith('//') ? `https:${raw}` : raw, baseUrl);
    if (!url || seen.has(url)) continue;

    seen.add(url);
    subtitles.push({
      url,
      ...subtitleMetadataNear(decoded, match.index || 0)
    });
  }

  return subtitles;
};

const uniqueSubtitles = (subtitles) => {
  const seen = new Set();
  return subtitles.filter((subtitle) => {
    if (!subtitle.url || seen.has(subtitle.url)) return false;
    seen.add(subtitle.url);
    return true;
  });
};

module.exports = {
  decodePayload,
  extractApiUrls,
  extractDocumentUrls,
  extractHlsUrls,
  extractIframeUrls,
  extractInlineScripts,
  extractScriptUrls,
  extractSubtitles,
  looksLikeDynamicScriptUrl,
  toAbsoluteUrl,
  unique,
  uniqueSubtitles
};
