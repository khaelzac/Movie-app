const { createProviderResolver } = require('./htmlProviderResolver');

const videasyResolver = createProviderResolver({
  name: 'videasy',
  maxPages: 8
});

module.exports = { videasyResolver };
