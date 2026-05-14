const axios = require('axios');
const { env } = require('../../config/env');
const { logResolverEvent } = require('./logger');

const DEFAULT_USER_AGENT = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  'AppleWebKit/537.36 (KHTML, like Gecko)',
  'Chrome/124.0.0.0 Safari/537.36'
].join(' ');

const defaultHeaders = (url, options = {}) => ({
  Accept: options.accept || '*/*',
  'Accept-Language': 'en-US,en;q=0.9',
  'Cache-Control': 'no-cache',
  Pragma: 'no-cache',
  Referer: options.referer || new URL(url).origin,
  'Sec-Fetch-Dest': options.destination || 'document',
  'Sec-Fetch-Mode': options.mode || 'navigate',
  'Sec-Fetch-Site': options.site || 'cross-site',
  'Upgrade-Insecure-Requests': options.upgradeInsecureRequests || '1',
  'User-Agent': options.userAgent || DEFAULT_USER_AGENT,
  ...(options.headers || {})
});

const sleep = (ms) => new Promise((resolve) => {
  setTimeout(resolve, ms);
});

const shouldRetry = (error) => {
  const status = error.response?.status;
  if ([408, 425, 429, 500, 502, 503, 504].includes(status)) return true;
  return ['ECONNABORTED', 'ECONNRESET', 'ETIMEDOUT', 'EAI_AGAIN'].includes(error.code);
};

const proxyPath = (baseUrl) => {
  const parsed = new URL(baseUrl);
  if (!parsed.pathname || parsed.pathname === '/') {
    parsed.pathname = '/proxy';
  }
  parsed.search = '';
  parsed.hash = '';
  return parsed;
};

const shouldUseResolverProxy = (url, options = {}) => {
  if (options.viaProxy === false) return false;
  if (!env.streamResolverViaProxy || !env.streamProxyBaseUrl) return false;

  try {
    const target = new URL(url);
    const proxy = proxyPath(env.streamProxyBaseUrl);
    return target.origin !== proxy.origin;
  } catch (_error) {
    return false;
  }
};

const resolverFetchUrl = (url, options = {}) => {
  if (!shouldUseResolverProxy(url, options)) return url;

  const proxyUrl = proxyPath(env.streamProxyBaseUrl);
  proxyUrl.searchParams.set('url', url);
  if (options.referer) proxyUrl.searchParams.set('referer', options.referer);
  return proxyUrl.toString();
};

const browserFetch = async (url, options = {}) => {
  const retries = options.retries ?? 1;
  const retryDelayMs = options.retryDelayMs ?? 250;
  const requestUrl = resolverFetchUrl(url, options);
  const viaProxy = requestUrl !== url;
  let lastError;

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const response = await axios.request({
        url: requestUrl,
        method: options.method || 'GET',
        data: options.data,
        timeout: options.timeoutMs,
        maxRedirects: options.maxRedirects ?? 5,
        responseType: options.responseType || 'text',
        headers: defaultHeaders(url, options),
        validateStatus: options.validateStatus || ((status) => status >= 200 && status < 400)
      });

      return {
        data: response.data,
        headers: response.headers,
        status: response.status,
        url: response.request?.res?.responseUrl || requestUrl
      };
    } catch (error) {
      lastError = error;
      if (viaProxy && attempt === 0) {
        logResolverEvent('warn', 'resolver_proxy_fetch_failed', {
          url,
          proxyUrl: requestUrl,
          status: error.response?.status,
          reason: error.message
        });
      }
      if (attempt >= retries || !shouldRetry(error)) break;
      await sleep(retryDelayMs * (attempt + 1));
    }
  }

  throw lastError;
};

const fetchText = async (url, options = {}) => {
  const response = await browserFetch(url, {
    ...options,
    responseType: 'text'
  });

  return String(response.data || '');
};

const fetchEmbedHtml = (url, options = {}) => fetchText(url, {
  ...options,
  accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  destination: 'document',
  mode: 'navigate'
});

const fetchScript = (url, options = {}) => fetchText(url, {
  ...options,
  accept: 'application/javascript,text/javascript,*/*;q=0.8',
  destination: 'script',
  mode: 'no-cors'
});

module.exports = {
  DEFAULT_USER_AGENT,
  browserFetch,
  fetchEmbedHtml,
  fetchScript,
  fetchText
};
