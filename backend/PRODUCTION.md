# Backend Production Notes

Recommended environment:

```text
NODE_ENV=production
ALLOWED_ORIGINS=https://your-frontend-origin.example
CACHE_TTL_SECONDS=900
STALE_CACHE_TTL_SECONDS=21600
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=120
REQUEST_TIMEOUT_MS=8000
EMBED_GATEWAY_BASE_URL=https://your-worker.workers.dev
EMBED_GATEWAY_SECRET=replace_with_a_long_random_secret
EMBED_TOKEN_TTL_SECONDS=900
EMBED_PROVIDERS=env-1,env-2
EMBED_PROVIDER_BLACKLIST=
EMBED_PROVIDER_SELECTION=random
```

The API uses compression, Helmet security headers, rate limiting, response cache headers, and in-flight TMDB request de-duplication.

Playback is embed-only. The backend signs Cloudflare Worker playback URLs and never resolves or returns raw media streams.
