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
STREAM_PROVIDER=disabled
VIDEASY_BASE_URL=
VIDSRC_BASE_URL=
```

The API now uses compression, Helmet security headers, rate limiting, response cache headers, and in-flight upstream request de-duplication.

Playback providers are selected by `STREAM_PROVIDER` and must be configured only for providers you are authorized to use.
