const { env } = require('../config/env');

const proxyPath = (baseUrl) => {
  const parsed = new URL(baseUrl);
  if (!parsed.pathname || parsed.pathname === '/') {
    parsed.pathname = '/proxy';
  }
  parsed.search = '';
  parsed.hash = '';
  return parsed;
};

const createProxiedHlsUrl = (streamUrl, referer) => {
  if (!env.streamProxyEnabled || !env.streamProxyBaseUrl) {
    return streamUrl;
  }

  const proxyUrl = proxyPath(env.streamProxyBaseUrl);
  proxyUrl.searchParams.set('url', streamUrl);
  if (referer) proxyUrl.searchParams.set('referer', referer);
  return proxyUrl.toString();
};

module.exports = { createProxiedHlsUrl };
