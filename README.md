# MovieApp

Production-oriented starter for a Netflix-like Flutter TV app with a secure Express TMDB proxy.

## Architecture

- `backend/`: Express REST API. TMDB API key stays here, loaded from `.env`.
- `frontend/`: Flutter app shell for Android TV, Google TV, mouse, keyboard, and touch.
- Frontend talks only to backend endpoints under `/api`.
- TMDB images are loaded by URL; TMDB API requests are proxied through the backend.

## Install Commands

Backend:

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

Frontend:

```bash
cd frontend
flutter create --platforms=android .
flutter pub get
flutter run
```

Android TV APK:

```bash
cd frontend
flutter build apk --release --split-per-abi
```

Vercel backend:

```bash
cd backend
vercel
vercel env add TMDB_API_KEY
vercel --prod
```

## Deployment

Full production deployment instructions are in:

- [DEPLOYMENT.md](DEPLOYMENT.md)
- [PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md)
- [RELEASE_WORKFLOW.md](RELEASE_WORKFLOW.md)

CI/CD workflows live in `.github/workflows/`.

## Backend Endpoints

- `GET /health`
- `GET /api/trending?page=1`
- `GET /api/movies/popular?page=1`
- `GET /api/tv/popular?page=1`
- `GET /api/top-rated?mediaType=movie&page=1`
- `GET /api/movie/:id`
- `GET /api/tv/:id`
- `GET /api/genres?mediaType=movie`
- `GET /api/search?query=matrix&page=1`
- `GET /api/recommendations/:id?mediaType=movie&page=1`
- `GET /api/similar/:id?mediaType=movie&page=1`
- `GET /api/genres/:slug?page=1`
- `GET /api/stream/movie/:tmdbId`
- `GET /api/stream/tv/:tmdbId/:season/:episode`

## Player Rule

TMDB is used only for metadata such as titles, posters, backdrops, genres, ratings, recommendations, and cast.

Playback source URLs are generated only by backend stream provider modules under `backend/src/providers`. The Flutter app never constructs playback provider URLs directly and does not use TMDB trailers or YouTube for playback.

## Next Prompt Workflow

1. Expand details pages with full TMDB details, cast, recommendations, and provider-backed playback.
2. Add TV navigation polish: focus memory per rail, D-pad auto-scroll, remote back handling, and top navigation.
3. Add paginated catalog pages for Trending, Popular, Top Rated, Genres, My List, and Continue Watching.
4. Add local persistence for My List and Continue Watching.
5. Add richer skeletons, shimmer states, image sizing variants, and low-memory optimizations.
6. Add backend tests and request validation hardening.
7. Finalize Android Gradle release settings, app icons, signing notes, and Vercel production config.
