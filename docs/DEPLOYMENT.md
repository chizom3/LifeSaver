# LifeSaver Deployment Guide

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
https://app.life-saver.com.ng/
```

The web Google Maps key should allow:

```text
https://app.life-saver.com.ng/*
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

## Web Bandwidth

The web app is tuned to download as little as possible:

- **Hospital data** (`assets/data/hospitals.json`) uses a compact column
  format: about 4.6 MB raw / 1.6 MB compressed, versus 25.6 MB / 3.1 MB for
  the original record-per-object export. To update the data, export it in
  the original `data-*` format and convert it:

  ```powershell
  python tool\compact_hospitals.py new_export.json assets\data\hospitals.json
  ```

  The script repairs known coordinate typos and refuses to write the file if
  any hospital's key would change (saved favorites and admin updates are
  keyed on it).
- **Google Maps** is loaded only when a visitor opens the Map tab
  (`web/maps_loader.js`), not on every page load.
- **CanvasKit** is fetched from Google's CDN (`gstatic.com`), which browsers
  share across sites. The local `canvaskit/` folder is uploaded but not
  normally downloaded.

### Server settings

Compression matters most: it cuts `main.dart.js` by about 70% and the
hospital data by about 65%. `web/.htaccess` (copied into `build\web`)
enables gzip/brotli and revalidation caching on Apache and LiteSpeed hosts.
On other servers, configure the equivalent:

- Compress `.js`, `.json`, `.wasm`, `.html`, `.otf`, `.ttf`.
- Send `Cache-Control: no-cache` with ETag/Last-Modified. Flutter web file
  names are not content-hashed, so long cache lifetimes would serve stale
  code after a deploy; revalidation makes unchanged files a small 304.

Check a deploy with:

```powershell
curl -sI -H "Accept-Encoding: gzip, br" https://<domain>/main.dart.js
```

The response should include `content-encoding: gzip` (or `br`).
