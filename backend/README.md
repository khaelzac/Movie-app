# OCAMPOFLIX Backend

Express.js TMDB proxy for the Flutter TV app. The TMDB API key lives only on the backend.

## Setup

```bash
npm install
cp .env.example .env
npm run dev
```

## Environment

```bash
PORT=4000
TMDB_API_KEY=your_tmdb_api_key_here
TMDB_BASE_URL=https://api.themoviedb.org/3
ALLOWED_ORIGINS=*
CACHE_TTL_SECONDS=900
STALE_CACHE_TTL_SECONDS=21600
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=120
REQUEST_TIMEOUT_MS=8000
STREAM_RESOLVE_RETRIES=2
STREAM_PROXY_BASE_URL=
STREAM_PROVIDER=disabled
STREAM_PROVIDERS=
VIDEASY_BASE_URL=
VIDSRC_BASE_URL=
```

## Endpoints

- `GET /health`
- `GET /api/trending?page=1&mediaType=all&timeWindow=week`
- `GET /api/movies/popular?page=1`
- `GET /api/tv/popular?page=1`
- `GET /api/top-rated?page=1&mediaType=movie`
- `GET /api/movie/:id`
- `GET /api/tv/:id`
- `GET /api/search?query=matrix&page=1`
- `GET /api/genres?mediaType=movie`
- `GET /api/recommendations/:id?mediaType=movie&page=1`
- `GET /api/similar/:id?mediaType=movie&page=1`
- `GET /api/stream/providers`
- `GET /api/stream/movie/:tmdbId`
- `GET /api/stream/movie/:tmdbId?provider=videasy`
- `GET /api/stream/tv/:tmdbId/:season/:episode`
- `GET /api/stream/tv/:tmdbId/:season/:episode?provider=vidsrc`

## Stream Providers

The stream endpoint uses `STREAM_PROVIDERS` to resolve direct HLS `.m3u8` streams from configured provider embeds, or falls back to `STREAM_PROVIDER` for a single provider. Keep playback providers backend-only.

Most public provider docs describe iframe embed URLs, not direct HLS APIs. The native Flutter player needs a resolved `.m3u8`; if a provider only supports browser iframe playback or blocks server-side resolution, configure a provider/API that explicitly returns playable HLS for your authorized use case.

Successful stream responses use this shape:

```json
{
  "provider": "env-8",
  "streamUrl": "https://cdn.example.com/master.m3u8",
  "referer": "https://provider.example",
  "subtitles": []
}
```

Set `STREAM_PROXY_BASE_URL` to a worker/proxy endpoint if clients need proxied HLS URLs. The backend appends `url` and `referer` query parameters.

Supported provider module names:

- `videasy`
- `vidsrc`
- `env-1` through `env-N` from `AUTHORIZED_EMBED_PROVIDER_N_*`
- `disabled`

Configure only providers you are authorized to use.

## Vercel

1. Create the project in Vercel from the `backend` folder.
2. Add `TMDB_API_KEY` in Vercel project environment variables.
3. Add `ALLOWED_ORIGINS` with your frontend origin for production.
4. Deploy with:

```bash
vercel --prod
```

For the full production workflow, see `../DEPLOYMENT.md`.
