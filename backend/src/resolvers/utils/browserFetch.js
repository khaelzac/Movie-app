const axios = require('axios');

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

const browserFetch = async (url, options = {}) => {
  const retries = options.retries ?? 1;
  const retryDelayMs = options.retryDelayMs ?? 250;
  let lastError;

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const response = await axios.request({
        url,
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
        url: response.request?.res?.responseUrl || url
      };
    } catch (error) {
      lastError = error;
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
