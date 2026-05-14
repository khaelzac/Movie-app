const { createProviderResolver } = require('./htmlProviderResolver');

const vidsrcResolver = createProviderResolver({
  name: 'vidsrc',
  maxPages: 10
});

module.exports = { vidsrcResolver };
