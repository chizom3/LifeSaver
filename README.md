# LifeSaver

LifeSaver is a Flutter emergency healthcare locator app. It helps users find nearby health facilities, call or navigate to them, save Medical ID details, and prepare SOS SMS alerts with location information.

## Core features

- Map and list views for health facilities.
- Search by hospital name, state, LGA, or ward.
- State and LGA filters.
- Saved/favorite hospitals.
- Hospital detail sheet with distance, location, phone, coordinates, call, directions, and report correction actions.
- Medical ID stored locally on device.
- Multiple emergency contacts.
- SOS SMS preview with current or last known location.
- Last-known-location fallback when GPS is unavailable.
- Firebase Analytics and Crashlytics integration.
- Privacy policy and emergency/medical disclaimer screens.

## Safety notes

LifeSaver is a support tool, not a replacement for official emergency services or medical advice. Facility data, phone numbers, and locations should be verified before production use. Users should confirm SOS message details before sending.

## Report submissions

Facility reports do not require Firebase by default. Reports are saved locally and prepared as an email fallback. Firestore submission can be enabled later in `ReportService` after Firebase rules and operations are ready.

## Development

Install dependencies:

```sh
flutter pub get
```

Run analysis:

```sh
dart analyze
```

Run tests:

```sh
flutter test
```

## Important setup

- Android requires a `MAPS_API_KEY` Gradle property or environment variable for Google Maps.
- Use separate Google Maps API keys for Android and Web. Restrict the Android key to package `com.rydertechnologies.lifesaver` plus the release/upload certificate SHA-1, and restrict the Web key to `https://app.life-saver.com.ng/*`.
- Android permissions currently cover internet access, fine/coarse location, image picking, and package visibility for phone, map, email, and SMS intents.
- Emergency contacts and Medical ID data are stored locally with `shared_preferences`.

## Documentation

- [Deployment Guide](docs/DEPLOYMENT.md): release builds, APK/web output paths, hosting, and domain notes.
- [Application Documentation](docs/APPLICATION.md): product purpose, user flows, modules, data model, and operations.
- [Configuration Guide](docs/CONFIGURATION.md): Firebase, Google Maps keys, admin access, and local web Maps config.
- [UI Guide](docs/UI.md): current responsive layouts for hospitals, map, filters, First Aid, and Medical ID.
- [Troubleshooting](docs/TROUBLESHOOTING.md): common build, web cache, service worker, Firebase, and Maps errors.
