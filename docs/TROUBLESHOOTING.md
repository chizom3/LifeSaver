# LifeSaver Troubleshooting

## Release Web Does Not Show New Changes

Flutter web may serve an old build from the browser service worker/cache.

Try:

```powershell
flutter build web --release
python -m http.server 8081 -d build\web
```

Open:

```text
http://localhost:8081
```

If it still shows old UI:

1. Open browser DevTools.
2. Go to Application.
3. Unregister the service worker.
4. Clear site data.
5. Hard refresh with `Ctrl + F5`.

An Incognito/InPrivate window is also useful for testing.

## Service Worker MIME Type Error

Error:

```text
Failed to register a ServiceWorker ... unsupported MIME type ('text/plain')
```

The local server is serving `flutter_service_worker.js` with the wrong MIME type. The app can still run, but offline caching will not register.

Use `flutter run -d chrome` for development, or a web server that serves `.js` files as JavaScript.

## Google Maps RefererNotAllowedMapError

Error:

```text
Google Maps JavaScript API error: RefererNotAllowedMapError
Your site URL to be authorized: http://localhost:8081/
```

The web Maps key does not allow that origin.

Add the exact local referrer in Google Cloud:

```text
http://localhost:8081/*
```

For production, allow:

```text
https://app.life-saver.com.ng/*
```

## Firestore Offline Warning

Warning:

```text
Could not reach Cloud Firestore backend. Backend didn't respond within 10 seconds.
```

The app will use offline mode until Firestore reconnects. Offline hospital data should still load.

Check:

- Internet connection.
- Firewall/VPN/browser blocking Firebase.
- Firebase project/API availability.
- Firestore rules and project configuration.

## Google Maps Marker Deprecation Warning

Warning:

```text
google.maps.Marker is deprecated
```

This is not currently blocking. Google recommends `AdvancedMarkerElement`, but `google.maps.Marker` still works. Migration can be done later.

## Android Release Build Java Out Of Memory

Error:

```text
There is insufficient memory for the Java Runtime Environment to continue.
Native memory allocation failed.
```

The Gradle daemon requested too much heap for the machine. The project now uses a smaller heap in:

```text
android/gradle.properties
```

Current setting:

```properties
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
```

Close other heavy apps before running:

```powershell
flutter build apk --release
```

## WebAssembly Dry Run Warnings

The web build may show warnings from `flutter_tts_web` about WebAssembly compatibility. The normal JavaScript web build still succeeds.

These warnings matter only if you plan to ship a Wasm web build.
