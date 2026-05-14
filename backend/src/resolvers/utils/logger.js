const logResolverEvent = (level, event, details = {}) => {
  const payload = Object.fromEntries(
    Object.entries(details).filter(([, value]) => value !== undefined && value !== null)
  );

  const logger = level === 'error' ? console.error : level === 'warn' ? console.warn : console.info;
  logger('[stream-resolver]', {
    event,
    ...payload
  });
};

module.exports = { logResolverEvent };
