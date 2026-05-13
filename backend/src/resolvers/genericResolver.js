const { createHtmlResolver } = require('./resolverUtils');

const genericResolver = createHtmlResolver({ name: 'generic' });

module.exports = { genericResolver };
