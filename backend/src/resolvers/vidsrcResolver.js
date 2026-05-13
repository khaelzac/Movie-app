const { createHtmlResolver } = require('./resolverUtils');

const vidsrcResolver = createHtmlResolver({ name: 'vidsrc' });

module.exports = { vidsrcResolver };
