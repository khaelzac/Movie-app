const BASE64_PATTERN = /(?:atob\(\s*["']([A-Za-z0-9+/=]{24,})["']\s*\)|["']([A-Za-z0-9+/=]{40,})["'])/g;

const decodeBase64 = (value) => {
  try {
    const decoded = Buffer.from(value, 'base64').toString('utf8');
    return /m3u8|jwplayer|sources?|file|playlist/i.test(decoded) ? decoded : '';
  } catch (_error) {
    return '';
  }
};

const baseN = (value, radix) => Number.parseInt(value, radix);

const unpackDeanEdwards = (source) => {
  const pattern = /eval\(function\(p,a,c,k,e,(?:r|d)\)\{[\s\S]*?\}\((['"])([\s\S]*?)\1\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(['"])([\s\S]*?)\5\.split\(['"]\|['"]\)/g;
  const unpacked = [];

  for (const match of source.matchAll(pattern)) {
    const payload = match[2]
      .replace(/\\'/g, "'")
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, '\\');
    const radix = Number.parseInt(match[3], 10);
    const count = Number.parseInt(match[4], 10);
    const dictionary = match[6].split('|');

    if (!radix || !count || dictionary.length === 0) continue;

    unpacked.push(payload.replace(/\b\w+\b/g, (token) => {
      const index = baseN(token, radix);
      if (Number.isNaN(index) || index < 0 || index >= count) return token;
      return dictionary[index] || token;
    }));
  }

  return unpacked;
};

const decodeScriptPayloads = (payload) => {
  const decoded = [];

  for (const match of payload.matchAll(BASE64_PATTERN)) {
    const value = match[1] || match[2];
    const text = decodeBase64(value);
    if (text) decoded.push(text);
  }

  decoded.push(...unpackDeanEdwards(payload));

  return decoded;
};

module.exports = {
  decodeBase64,
  decodeScriptPayloads,
  unpackDeanEdwards
};
