# LifeSaver Application Documentation

## 1. Purpose

LifeSaver is an emergency healthcare locator application. It helps users find nearby health facilities, view first aid guidance, store Medical ID information, and prepare SOS messages with location details.

The app is a support tool. It does not replace emergency services, professional medical advice, or official facility verification.

## 2. Target Users

Primary users:

- People who need to quickly find nearby hospitals or primary health facilities.
- People who want offline first aid guidance.
- People who want to keep emergency contacts and Medical ID details available on their device.

Admin users:

- Approved operators who review hospital reports, verification information, and hospital data updates.

## 3. Main Features

### Hospital Locator

Users can:

- Browse health facilities in a list.
- View facilities on a map.
- Search by hospital name, state, LGA, or ward.
- Filter by state, LGA, saved hospitals, and distance.
- Sort by nearest or A-Z.
- Save favorite hospitals.
- Call a facility when a phone number is available.
- Open directions in Google Maps.
- View hospital details.
- Report incorrect or updated facility information.

### Map View

The map view shows filtered facilities and the user's current or last known location when available. It shares the same search/filter behavior as the hospital list.

### First Aid Guides

Users can:

- Search first aid topics.
- Browse first aid topics grouped by category.
- Open detailed first aid instructions.
- Use text-to-speech where supported.
- Call emergency services from guide details.
- Switch back to hospital search when medical care is needed.

First aid content is offline-first and loaded from app assets.

### Medical ID

Users can store:

- Full name.
- Age.
- Blood type.
- Address.
- Critical warning.
- Known conditions.
- Allergies.
- Current medications.
- Preferred hospital.
- Additional notes.
- Emergency contacts.
- Optional profile photo.

Medical ID information is stored locally on the device. It can be copied or displayed as a QR code for responders.

### SOS Alert

Users can prepare an SOS message for emergency contacts. The SOS message can include:

- Medical ID details.
- Current location when available.
- Last known location when current GPS is unavailable.

Users still confirm/send using the device's SMS flow.

### Emergency Mode

Emergency Mode gives quick access to:

- Call 112.
- Send SOS.
- First Aid.
- Nearest Hospital.

### Admin Area

Admin users can sign in and access management screens. Production admin access must be enforced with Firebase custom claims and Firestore rules, not client-side email checks.

## 4. User Flows

### Find A Hospital

1. User opens LifeSaver.
2. App loads offline hospital data.
3. App attempts to get current location.
4. User views nearby facilities in the hospital list.
5. User taps `Search` to filter if needed.
6. User opens a hospital detail, calls, saves, reports, or opens directions.

### Use Search And Filters

Mobile:

1. User taps `Search`.
2. A bottom sheet opens.
3. User searches or changes filters.
4. Results update behind the sheet.
5. User closes the sheet to continue browsing.

Web/desktop:

1. User taps `Search`.
2. A left sidebar opens.
3. User searches or changes filters.
4. Results update in the main content area.
5. User taps `Hide filters` to close the sidebar.

### Use First Aid

1. User opens the First Aid tab.
2. Topics are shown by category.
3. User expands a category or searches for a topic.
4. User opens a guide.
5. User follows the instructions, calls emergency services, or finds hospitals if needed.

### Set Up Medical ID

1. User opens Medical ID from the app menu or setup prompt.
2. User taps edit.
3. User fills the expandable sections.
4. User saves the data locally.
5. SOS and QR/copy features can use the saved details.

### Send SOS

1. User taps the SOS floating action button or uses Emergency Mode.
2. App builds an SOS message from emergency contacts, Medical ID, and location data.
3. User chooses recipients.
4. Device SMS app opens for final sending.

## 5. Application Structure

Important files:

```text
lib/main.dart
```

Main app entry point, app shell, hospital/map/first aid navigation, search/filter state, SOS entry points, and admin access routing.

```text
lib/profile_page.dart
```

Medical ID screen, local profile fields, emergency contacts, QR/copy, and profile photo handling.

```text
lib/hospital.dart
```

Hospital model and formatting helpers.

```text
lib/first_aid_guide.dart
```

First aid guide model.

```text
lib/repositories/hospital_repository.dart
```

Loads hospital data from assets, filters, sorts, applies cloud updates, and performs spatial/radius filtering.

```text
lib/repositories/first_aid_repository.dart
```

Loads and filters offline first aid topics.

```text
lib/widgets/
```

Screen and component widgets for hospital list, map, search filters, first aid, admin, onboarding, privacy, disclaimer, SOS sheets, and emergency mode.

```text
lib/services/
```

Local and external service wrappers for location, favorites, reports, SOS, Firebase admin auth, hospital updates, hospital verification, and first aid voice.

## 6. Data Sources

### Offline Assets

Hospital data:

```text
assets/data/hospitals.json
```

First aid data:

```text
assets/data/first_aid_guides.json
```

These are bundled into the app and work offline.

### Local Device Storage

The app uses `shared_preferences` for:

- Medical ID details.
- Emergency contacts.
- Favorite hospitals.
- Onboarding/disclaimer state.
- Last known location metadata.
- Pending/local report fallback data.

### Firebase

Firebase is used for:

- Firestore hospital update overlays.
- Report and verification workflows.
- Admin auth/custom claim checks.
- Analytics.
- Crashlytics.

If Firestore is unavailable, the app can still load offline hospital data and first aid topics.

## 7. External Integrations

### Google Maps

Used for:

- In-app map display.
- Hospital markers.
- Directions handoff.

Android and Web should use separate restricted API keys.

### Geolocation

Used for:

- Current location.
- Nearby hospital sorting.
- Radius filters.
- SOS location text.

The app can fall back to last known location.

### URL Launcher

Used for:

- Phone calls.
- SMS.
- Email/report fallback.
- External map directions.

### Contacts

Used for selecting emergency contacts from the device when supported.

### Text-To-Speech

Used in First Aid detail screens where supported.

## 8. Security And Privacy

Medical ID and emergency contacts are sensitive. They are stored locally on the user's device.

Operational rules:

- Do not commit real API keys to git.
- Restrict Maps API keys by package/SHA or HTTP referrer.
- Use Firebase custom claims for admin access.
- Keep Android keystores and `key.properties` out of git.
- Keep Firestore rules strict in production.
- Treat hospital reports and verification updates as untrusted until reviewed.

## 9. Platform Behavior

### Android

Primary production target. Supports location, maps, phone intents, SMS, image picker, contacts, and local storage.

Release output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

### Web

Useful for desktop access and public deployment. Supports hospital search, map display, first aid, and Firebase integrations. Some mobile-native flows depend on browser support.

Release output:

```text
build\web
```

Production domain:

```text
https://app.life-saver.com.ng/
```

## 10. Known Operational Notes

- Release web builds may be hidden by old browser service worker cache. Clear site data or test on a new port.
- Local web Maps testing requires the current localhost port to be allowed on the web Maps key.
- Firestore warnings do not stop offline hospital data from loading.
- Google Maps Marker deprecation warnings are not currently blocking.
- Android release builds need Gradle memory settings that fit the local machine.

## 11. Build And Test Commands

Install dependencies:

```powershell
flutter pub get
```

Run tests:

```powershell
flutter test
```

Run analysis:

```powershell
flutter analyze
```

Build Android APK:

```powershell
flutter build apk --release
```

Build Web:

```powershell
flutter build web --release
```

Serve release web locally:

```powershell
python -m http.server 8081 -d build\web
```

Open:

```text
http://localhost:8081
```

## 12. Maintenance Checklist

Before a public release:

- Run `flutter test`.
- Run `flutter analyze`.
- Build Android release APK.
- Build web release.
- Test hospital list search/filter on mobile and web.
- Test map on Android and web.
- Test First Aid grouping and guide details.
- Test Medical ID save/copy/QR.
- Test SOS preview and SMS handoff.
- Confirm Google Maps restrictions.
- Confirm Firebase rules.
- Confirm admin custom claims.
- Confirm no secrets are committed.
