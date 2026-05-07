# Google Maps API Key Restrictions

Use separate Google Maps API keys per platform. Google Cloud application restrictions are platform-specific, so one key should not be shared between Android package/SHA restrictions and Web referrer restrictions.

Configured Google Cloud project:

- Project ID: `life-saver-17939`
- Project number: `1019209914571`

## Android Key

Application restriction:

- Android apps

Created key:

- Display name: `MediMap Android Maps key`
- Resource: `projects/1019209914571/locations/global/keys/fef67123-1364-459f-8b32-2c8e694bbd1d`

Allowed Android app:

- Package name: `com.rydertechnologies.medimap`
- SHA-1 certificate fingerprint: use the release/upload keystore SHA-1 before publishing

Local debug fingerprint for development only:

- SHA-1: `AC:07:32:E7:2B:21:B6:21:74:41:40:89:F7:D4:11:5A:76:B0:C7:44`
- SHA-256: `7E:7E:01:14:AC:8F:BB:AA:88:44:D8:30:E7:9C:38:51:8B:59:09:07:A4:C3:7A:5B:45:86:FB:09:31:EF:E1:60`

Generated release/upload fingerprint:

- SHA-1: `63:39:B2:93:AF:1E:E8:89:30:CF:9C:07:65:85:5A:BC:FA:14:A2:4C`
- SHA-256: `F7:DB:0F:E6:8F:9F:20:77:4C:62:6D:D7:15:8F:75:11:72:9A:2B:D0:91:44:03:FB:58:E7:9F:E3:B3:06:BA:11`

API restrictions:

- Maps SDK for Android

Set the Android key as `MAPS_API_KEY` in `android/local.properties`, a Gradle property, or the environment used for release builds.

## Web Key

Application restriction:

- Websites

Created key:

- Display name: `MediMap Web Maps key`
- Resource: `projects/1019209914571/locations/global/keys/39f21d3d-80b5-4d45-b472-aa0985f68767`

Allowed referrers:

- Your production domain, for example `https://example.com/*`
- Firebase Hosting domains if used, for example `https://life-saver-17939.web.app/*` and `https://life-saver-17939.firebaseapp.com/*`
- Local development domains only while needed, for example `http://localhost:*/*`

API restrictions:

- Maps JavaScript API

The Web key is loaded in `web/index.html`.
