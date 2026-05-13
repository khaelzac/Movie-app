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

The stream endpoint uses `STREAM_PROVIDERS` to expose multiple configured provider modules, or falls back to `STREAM_PROVIDER` for a single provider. Keep playback providers backend-only.

Supported provider module names:

- `videasy`
- `vidsrc`
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
