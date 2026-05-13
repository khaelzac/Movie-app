# MovieApp Deployment Guide

This guide deploys the Express backend to Vercel and builds a production Android TV release from Flutter.

## 1. Accounts And Tools

Install locally:

```bash
node --version
npm --version
flutter --version
java -version
```

You need:

- A TMDB API key.
- A Vercel account.
- A GitHub repo for CI/CD.
- A Java JDK 17 install for Android release builds.
- Flutter stable installed locally.

## 2. Backend: Vercel

From the backend folder:

```bash
cd backend
npm install
npm run check
npm audit --audit-level=moderate
```

Install and login to Vercel:

```bash
npm install -g vercel
vercel login
```

Link or create the Vercel project:

```bash
cd backend
vercel link
```

Set production environment variables:

```bash
vercel env add TMDB_API_KEY production
vercel env add TMDB_BASE_URL production
vercel env add ALLOWED_ORIGINS production
vercel env add CACHE_TTL_SECONDS production
vercel env add STALE_CACHE_TTL_SECONDS production
vercel env add RATE_LIMIT_WINDOW_MS production
vercel env add RATE_LIMIT_MAX production
vercel env add REQUEST_TIMEOUT_MS production
vercel env add STREAM_PROVIDER production
vercel env add STREAM_PROVIDERS production
vercel env add CUSTOM_EMBED_NAME production
vercel env add CUSTOM_EMBED_BASE_URL production
vercel env add CUSTOM_EMBED_MOVIE_PATTERN production
vercel env add CUSTOM_EMBED_TV_PATTERN production
vercel env add VIDEASY_BASE_URL production
vercel env add VIDSRC_BASE_URL production
```

Recommended values:

```text
TMDB_BASE_URL=https://api.themoviedb.org/3
ALLOWED_ORIGINS=*
CACHE_TTL_SECONDS=900
STALE_CACHE_TTL_SECONDS=21600
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=120
REQUEST_TIMEOUT_MS=8000
STREAM_PROVIDER=disabled
STREAM_PROVIDERS=
CUSTOM_EMBED_NAME=
CUSTOM_EMBED_BASE_URL=
CUSTOM_EMBED_MOVIE_PATTERN=/movie/{tmdb_id}
CUSTOM_EMBED_TV_PATTERN=/tv/{tmdb_id}/{season}/{episode}
VIDEASY_BASE_URL=
VIDSRC_BASE_URL=
```

Deploy:

```bash
vercel --prod
```

Verify:

```bash
curl https://movie-app-gamma-sand-21.vercel.app/health
curl "https://movie-app-gamma-sand-21.vercel.app/api/trending?page=1"
curl "https://movie-app-gamma-sand-21.vercel.app/api/stream/movie/687163"
```

If `STREAM_PROVIDER=disabled`, stream endpoints return `501` until an authorized provider base URL is configured.

## 3. Frontend: Backend URL

Before building production Android, point the Flutter app at your deployed backend in `frontend/lib/core/constants/app_constants.dart`:

```dart
static const backendBaseUrl = 'https://movie-app-gamma-sand-21.vercel.app/api';
```

Use local emulator URL only for debug builds.

## 4. Android Release Signing

Create a release keystore:

```bash
cd frontend
keytool -genkey -v -keystore android/app/movieapp-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias movieapp
```

Create `frontend/android/key.properties`:

```text
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=movieapp
storeFile=app/movieapp-release.jks
```

Do not commit `key.properties` or `.jks` files.

## 5. Build Android TV APK And App Bundle

Install dependencies:

```bash
cd frontend
flutter pub get
flutter analyze
```

Build a Google Play app bundle:

```bash
flutter build appbundle --release --split-debug-info=build/symbols --obfuscate
```

Build APKs for sideload testing:

```bash
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
```

Outputs:

- App bundle: `frontend/build/app/outputs/bundle/release/app-release.aab`
- Split APKs: `frontend/build/app/outputs/flutter-apk/`
- Dart symbols: `frontend/build/symbols/`

## 6. Install APK On Android TV

Enable developer mode and USB debugging on the TV, then:

```bash
adb devices
adb install -r frontend/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Most Android TV devices use `arm64-v8a`.

## 7. GitHub Actions Secrets

Backend Vercel deploy secrets:

```text
VERCEL_TOKEN
VERCEL_ORG_ID
VERCEL_PROJECT_ID
```

Android signing secrets:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_PASSWORD
ANDROID_KEY_ALIAS
```

Create `ANDROID_KEYSTORE_BASE64`:

```bash
base64 -w 0 frontend/android/app/movieapp-release.jks
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("frontend/android/app/movieapp-release.jks"))
```

## 8. Release Workflow

1. Update version in `frontend/pubspec.yaml`.
2. Confirm backend env vars in Vercel.
3. Confirm `backendBaseUrl` points to production.
4. Run backend checks.
5. Run Flutter analyze.
6. Build app bundle and APK.
7. Sideload test on Android TV.
8. Tag release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

9. Download GitHub Actions artifacts.
10. Upload `.aab` to Google Play Console or distribute APK internally.
