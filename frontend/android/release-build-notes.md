# Android TV Release Build Notes

Use app bundles for store releases and split APKs for sideload testing:

```powershell
flutter build appbundle --release --split-debug-info=build/symbols --obfuscate
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
```

Release builds enable R8 minification and resource shrinking in `app/build.gradle`.

Before store release, replace the debug signing config in `android/app/build.gradle` with a real release keystore.
