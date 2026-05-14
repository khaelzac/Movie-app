const { createProviderResolver } = require('./htmlProviderResolver');

const nontongoResolver = createProviderResolver({
  name: 'nontongo',
  maxPages: 8
});

module.exports = { nontongoResolver };
