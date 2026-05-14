const { directHlsResolver } = require('./directHlsResolver');
const { nontongoResolver } = require('./nontongoResolver');
const { twoEmbedResolver } = require('./twoEmbedResolver');
const { videasyResolver } = require('./videasyResolver');
const { vidlinkResolver } = require('./vidlinkResolver');
const { vidsrcResolver } = require('./vidsrcResolver');

const hostname = (value) => {
  try {
    return new URL(value).hostname.replace(/^www\./, '').toLowerCase();
  } catch (_error) {
    return '';
  }
};

const providerResolvers = [
  {
    resolver: directHlsResolver,
    matches: ({ provider }) => (
      /^(direct-hls|hls|api)$/i.test(provider.resolver || '') ||
      /direct hls|hls api/i.test(provider.label || provider.name)
    )
  },
  {
    resolver: vidlinkResolver,
    matches: ({ provider, source }) => (
      provider.name === 'env-2' ||
      /vidlink/i.test(provider.label || provider.name) ||
      hostname(source.url) === 'vidlink.pro'
    )
  },
  {
    resolver: nontongoResolver,
    matches: ({ provider, source }) => (
      provider.name === 'env-8' ||
      /nontongo/i.test(provider.label || provider.name) ||
      hostname(source.url) === 'nontongo.com'
    )
  },
  {
    resolver: twoEmbedResolver,
    matches: ({ provider, source }) => (
      provider.name === 'env-1' ||
      /2embed/i.test(provider.label || provider.name) ||
      hostname(source.url) === '2embed.to'
    )
  },
  {
    resolver: videasyResolver,
    matches: ({ provider, source }) => (
      provider.name === 'videasy' ||
      /videasy/i.test(provider.label || provider.name) ||
      /videasy/i.test(hostname(source.url))
    )
  },
  {
    resolver: vidsrcResolver,
    matches: ({ provider, source }) => (
      provider.name === 'vidsrc' ||
      /^env-(3|5|6|7|9|10)$/.test(provider.name) ||
      /vidsrc|vsrc|vsemembed/i.test(provider.label || provider.name) ||
      /(?:vidsrc|vsrc|vsemembed)/i.test(hostname(source.url))
    )
  }
];

const resolverForProvider = (provider, source) => {
  const match = providerResolvers.find((item) => item.matches({ provider, source }));
  if (!match) {
    const error = new Error(`No resolver registered for playback provider "${provider.name}".`);
    error.status = 501;
    throw error;
  }
  return match.resolver;
};

module.exports = {
  providerResolvers,
  resolverForProvider
};
