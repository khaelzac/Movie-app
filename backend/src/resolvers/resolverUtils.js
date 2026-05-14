const { createProviderResolver } = require('./providers/htmlProviderResolver');
const { fetchEmbedHtml, fetchText } = require('./utils/browserFetch');
const {
  extractDocumentUrls: documentUrlsFrom,
  extractHlsUrls: extractM3u8Urls,
  extractSubtitles,
  toAbsoluteUrl
} = require('./utils/sourceExtractor');
const { payloadFromHtml: extractScriptPayload } = require('./utils/iframeCrawler');

const createHtmlResolver = ({ name }) => createProviderResolver({ name });

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
