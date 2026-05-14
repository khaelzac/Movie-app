const { createProviderResolver } = require('./htmlProviderResolver');

const twoEmbedResolver = createProviderResolver({
  name: '2embed',
  maxPages: 10
});

module.exports = { twoEmbedResolver };
