# MediMap Deployment Guide

This guide covers local verification, Android release builds, and web release builds.

## Verify Before Release

Run:

```powershell
flutter test
flutter analyze
```

On this Windows machine, `flutter analyze` may need to run outside the sandbox/tool wrapper. If it hangs in an automated environment, run it directly in PowerShell.

## Android Release APK

Build:

```powershell
flutter build apk --release
```

Output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

The project Gradle heap is intentionally set lower in `android/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
```

This avoids Java out-of-memory crashes on machines with limited RAM.

## Web Release

Build:

```powershell
flutter build web --release
```

Output:

```text
build\web
```

Test locally:

```powershell
python -m http.server 8081 -d build\web
```

Open:

```text
http://localhost:8081
```

Do not open `build\web\index.html` directly. Flutter web should be served through a web server.

## Production Domain

Production web domain:

```text
https://medimap.ryderenergy.com.ng/
```

The web Google Maps key should allow:

```text
https://medimap.ryderenergy.com.ng/*
```

For local web testing, temporarily allow:

```text
http://localhost:8081/*
```

Remove broad localhost access from production keys when local testing is done.

## Web Hosting Notes

When deploying `build\web`, host the entire folder contents. Required files include:

- `index.html`
- `main.dart.js`
- `flutter_bootstrap.js`
- `flutter_service_worker.js`
- `assets/`
- `canvaskit/`
- `maps_loader.js`
- `maps_config.js` or an equivalent environment-specific Maps key loader

For production, do not commit secrets into the repository. Inject the web Maps key during deployment or keep environment-specific config outside git.
