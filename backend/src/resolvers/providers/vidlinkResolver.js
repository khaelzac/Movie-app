const { createProviderResolver } = require('./htmlProviderResolver');

const vidlinkResolver = createProviderResolver({
  name: 'vidlink',
  maxPages: 8
});

module.exports = { vidlinkResolver };
