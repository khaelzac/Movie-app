const store = new Map();
const inflight = new Map();

const now = () => Date.now();

const get = (key) => {
  const entry = store.get(key);
  if (!entry) return null;

  if (entry.expiresAt <= now()) {
    store.delete(key);
    return null;
  }

  return entry.value;
};

const set = (key, value, ttlSeconds) => {
  store.set(key, {
    value,
    expiresAt: now() + (ttlSeconds * 1000)
  });
  return value;
};

const getOrSet = async (key, fetcher, ttlSeconds) => {
  const cached = get(key);
  if (cached) return cached;

  if (inflight.has(key)) return inflight.get(key);

  const pending = fetcher()
    .then((value) => set(key, value, ttlSeconds))
    .finally(() => {
      inflight.delete(key);
    });

  inflight.set(key, pending);
  return pending;
};

const clear = () => {
  store.clear();
  inflight.clear();
};

module.exports = {
  clear,
  get,
  getOrSet,
  set
};
