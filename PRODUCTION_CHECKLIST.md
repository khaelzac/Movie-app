# Production Checklist

## Backend

- `TMDB_API_KEY` is set in Vercel production.
- `ALLOWED_ORIGINS` is restricted when a production frontend origin exists.
- `NODE_ENV=production`.
- `npm ci` succeeds.
- `npm run check` succeeds.
- `npm audit --audit-level=moderate` reports no vulnerabilities.
- `/health` returns `{ "ok": true }`.
- `/api/trending?page=1` returns data.
- Embed endpoints return a backend-generated Cloudflare Worker URL when an authorized provider is configured.
- Flutter never constructs playback provider URLs directly.
- TMDB trailers and YouTube are not used for playback.
- Rate limit values are appropriate for expected traffic.
- Vercel production deployment is linked to the correct GitHub repo.

## Frontend

- `backendBaseUrl` points to the production Vercel API.
- `flutter pub get` succeeds.
- `flutter analyze` succeeds.
- Android release keystore exists locally or in CI secrets.
- Release build uses `--obfuscate --split-debug-info=build/symbols`.
- Dart symbols are archived.
- APK is sideload tested on Android TV.
- D-pad navigation works on Home, Search, Genres, Details, My List.
- Images load and scrolling remains smooth on a low-memory TV device.
- My List and Continue Watching persist after app restart.

## Android TV Store Readiness

- App label is final.
- App icon/banner assets are final.
- Release build is signed with the production keystore.
- `usesCleartextTraffic=false` for release.
- App bundle is uploaded to Play Console.
- Privacy policy and content metadata are ready if publishing publicly.

## Release

- Version number in `frontend/pubspec.yaml` is bumped.
- Git tag is created from the exact release commit.
- GitHub Actions backend and Android workflows pass.
- Vercel production URL is verified after deploy.
- Release notes mention backend URL, app version, and known limitations.
