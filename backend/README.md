# OCAMPOFLIX Backend

Express.js API for TMDB metadata and secure embed playback URL generation. The backend does not extract streams, parse provider HTML, manipulate playlists, or return raw media URLs.

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

EMBED_GATEWAY_BASE_URL=https://your-worker.workers.dev
EMBED_GATEWAY_SECRET=replace_with_a_long_random_secret
EMBED_TOKEN_TTL_SECONDS=900
EMBED_PROVIDERS=env-1,env-2
EMBED_PROVIDER_BLACKLIST=
EMBED_PROVIDER_SELECTION=random

AUTHORIZED_EMBED_PROVIDER_1_ENABLED=true
EMBED_PROVIDER_ENV_1_HEALTH_SCORE=100

AUTHORIZED_EMBED_PROVIDER_1_NAME=VidLink
AUTHORIZED_EMBED_PROVIDER_1_BASE_URL=https://vidlink.pro
AUTHORIZED_EMBED_PROVIDER_1_MOVIE_PATTERN=/movie/{tmdb_id}
AUTHORIZED_EMBED_PROVIDER_1_TV_PATTERN=/tv/{tmdb_id}/{season}/{episode}
```

## Endpoints

- `GET /health`
- `GET /api/trending?page=1&mediaType=all&timeWindow=week`
- `GET /api/movies/popular?page=1`
- `GET /api/tv/popular?page=1`
- `GET /api/top-rated?page=1&mediaType=movie`
- `GET /api/movie/:id`
- `GET /api/tv/:id`
- `GET /api/tv/:id/season/:season`
- `GET /api/search?query=matrix&page=1`
- `GET /api/genres?mediaType=movie`
- `GET /api/recommendations/:id?mediaType=movie&page=1`
- `GET /api/similar/:id?mediaType=movie&page=1`
- `GET /api/embed/providers`
- `GET /api/embed/movie/:tmdbId`
- `GET /api/embed/movie/:tmdbId?provider=env-1`
- `GET /api/embed/tv/:tmdbId/:season/:episode`
- `GET /api/embed/tv/:tmdbId/:season/:episode?provider=env-1`

## Embed Playback

The embed endpoints choose a configured authorized provider, build the provider iframe URL, sign a short-lived payload, and return a Cloudflare Worker playback URL:

```json
{
  "success": true,
  "provider": "VidLink",
  "embedUrl": "https://your-worker.workers.dev/embed?token=...&signature=..."
}
```

Provider config lives in `src/config/embedProviders.js`. Configure only providers you are authorized to embed.

Example provider utility usage:

```js
const {
  chooseEmbedProvider,
  buildMovieEmbedUrl,
  buildTvEmbedUrl
} = require('./src/config/embedProviders');

const provider = chooseEmbedProvider({ strategy: 'best-health' });
const movieUrl = buildMovieEmbedUrl(provider, 550);
const tvUrl = buildTvEmbedUrl(provider, 1399, 1, 1);
```

## Vercel

1. Create the project in Vercel from the `backend` folder.
2. Add `TMDB_API_KEY`, `EMBED_GATEWAY_BASE_URL`, and `EMBED_GATEWAY_SECRET`.
3. Add `ALLOWED_ORIGINS` with your frontend origin for production.
4. Deploy with:

```bash
vercel --prod
```
