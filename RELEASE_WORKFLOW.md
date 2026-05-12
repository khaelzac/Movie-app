# Release Workflow

Use this workflow for every production release.

## 1. Prepare

```bash
git status
```

Make sure only intended files are changed.

Update version in `frontend/pubspec.yaml`:

```yaml
version: 0.1.1+2
```

## 2. Backend Validation

```bash
cd backend
npm ci
npm run check
npm audit --audit-level=moderate
```

Deploy to Vercel:

```bash
vercel --prod
```

Verify:

```bash
curl https://movie-app-gamma-sand-21.vercel.app/health
curl "https://movie-app-gamma-sand-21.vercel.app/api/trending?page=1"
```

## 3. Frontend Validation

Set production backend URL in `frontend/lib/core/constants/app_constants.dart`.

```bash
cd frontend
flutter pub get
flutter analyze
flutter build appbundle --release --split-debug-info=build/symbols --obfuscate
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
```

Sideload the ARM64 APK:

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 4. TV Smoke Test

- Launch app cold.
- Confirm splash reaches profile/home.
- D-pad through hero buttons and rails.
- Open details.
- Add item to My List.
- Open trailer/watch options and confirm Continue Watching appears.
- Search with remote/keyboard.
- Browse Genres.
- Restart app and confirm local persistence.

## 5. Tag

```bash
git add .
git commit -m "Release v0.1.1"
git tag v0.1.1
git push origin main
git push origin v0.1.1
```

## 6. Publish

- Upload `app-release.aab` to Google Play Console.
- Keep split APKs for sideload/internal QA.
- Store `build/symbols/` with the release artifacts.
- Confirm Vercel production deployment is healthy.
