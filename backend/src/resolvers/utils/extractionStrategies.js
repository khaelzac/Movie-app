const { decodeScriptPayloads } = require('./scriptDecoder');
const { decodePayload, toAbsoluteUrl, unique } = require('./sourceExtractor');

const normalizeCandidate = (url, baseUrl, strategy) => {
  const normalized = toAbsoluteUrl(url?.startsWith('//') ? `https:${url}` : url, baseUrl);
  return normalized ? { url: normalized, strategy } : null;
};

const directHlsStrategy = (payload, baseUrl) => {
  const candidates = [];
  const decoded = decodePayload(payload);
  const patterns = [
    /https?:\/\/[^\s"'<>\\)]+?\.m3u8(?:\?[^\s"'<>\\)]*)?/gi,
    /\/\/[^\s"'<>\\)]+?\.m3u8(?:\?[^\s"'<>\\)]*)?/gi,
    /["']([^"']+?\.m3u8(?:\?[^"']*)?)["']/gi
  ];

  for (const pattern of patterns) {
    for (const match of decoded.matchAll(pattern)) {
      const candidate = normalizeCandidate(match[1] || match[0], baseUrl, 'direct-url');
      if (candidate) candidates.push(candidate);
    }
  }

  return candidates;
};

const jwPlayerStrategy = (payload, baseUrl) => {
  const candidates = [];
  const decoded = decodePayload(payload);
  const setupBlocks = [
    ...decoded.matchAll(/jwplayer\s*\([^)]*\)\s*\.setup\s*\(\s*(\{[\s\S]{0,6000}?\})\s*\)/gi),
    ...decoded.matchAll(/setup\s*:\s*(\{[\s\S]{0,6000}?\})/gi)
  ];

  for (const block of setupBlocks) {
    candidates.push(...directHlsStrategy(block[1], baseUrl).map((item) => ({
      ...item,
      strategy: 'jwplayer-config'
    })));
  }

  return candidates;
};

const sourcesArrayStrategy = (payload, baseUrl) => {
  const candidates = [];
  const decoded = decodePayload(payload);
  const sourceBlocks = [
    ...decoded.matchAll(/sources?\s*[:=]\s*(\[[\s\S]{0,6000}?\])/gi),
    ...decoded.matchAll(/playlist\s*[:=]\s*(\[[\s\S]{0,6000}?\])/gi)
  ];

  for (const block of sourceBlocks) {
    const urls = [
      ...block[1].matchAll(/(?:file|url|src)\s*[:=]\s*["']([^"']+?\.m3u8(?:\?[^"']*)?)["']/gi),
      ...block[1].matchAll(/["']([^"']+?\.m3u8(?:\?[^"']*)?)["']/gi)
    ];

    for (const match of urls) {
      const candidate = normalizeCandidate(match[1], baseUrl, 'sources-array');
      if (candidate) candidates.push(candidate);
    }
  }

  return candidates;
};

const jsonBlobStrategy = (payload, baseUrl) => {
  const candidates = [];
  const decoded = decodePayload(payload);
  const jsonScripts = decoded.match(/<script[^>]+type=["']application\/(?:json|ld\+json)["'][^>]*>([\s\S]*?)<\/script>/gi) || [];
  const assignments = [
    ...decoded.matchAll(/(?:player|config|sources|playlist|data)\s*=\s*(\{[\s\S]{0,10000}?\});/gi),
    ...decoded.matchAll(/(?:player|config|sources|playlist|data)\s*:\s*(\{[\s\S]{0,10000}?\})/gi)
  ].map((match) => match[1]);

  for (const script of jsonScripts) {
    candidates.push(...directHlsStrategy(script.replace(/<[^>]+>/g, ''), baseUrl).map((item) => ({
      ...item,
      strategy: 'json-script'
    })));
  }

  for (const blob of assignments) {
    candidates.push(...directHlsStrategy(blob, baseUrl).map((item) => ({
      ...item,
      strategy: 'json-blob'
    })));
  }

  return candidates;
};

const decodedPayloadStrategy = (payload, baseUrl, depth) => decodeScriptPayloads(payload)
  .flatMap((decoded) => extractHlsCandidates(decoded, baseUrl, { decodedDepth: depth + 1 })
    .map((candidate) => ({
      ...candidate,
      strategy: candidate.strategy === 'direct-url' ? 'decoded-script' : `decoded-${candidate.strategy}`
    })));

const extractHlsCandidates = (payload, baseUrl, options = {}) => {
  const decodedDepth = options.decodedDepth || 0;
  const candidates = [
    ...jwPlayerStrategy(payload, baseUrl),
    ...sourcesArrayStrategy(payload, baseUrl),
    ...jsonBlobStrategy(payload, baseUrl),
    ...directHlsStrategy(payload, baseUrl)
  ];

  if (decodedDepth < 2) {
    candidates.push(...decodedPayloadStrategy(payload, baseUrl, decodedDepth));
  }

  const seen = new Set();
  return candidates.filter((candidate) => {
    if (!candidate?.url || seen.has(candidate.url)) return false;
    seen.add(candidate.url);
    return true;
  });
};

const extractHlsUrls = (payload, baseUrl) => unique(
  extractHlsCandidates(payload, baseUrl).map((candidate) => candidate.url)
);

module.exports = {
  directHlsStrategy,
  extractHlsCandidates,
  extractHlsUrls,
  jsonBlobStrategy,
  jwPlayerStrategy,
  sourcesArrayStrategy
};
