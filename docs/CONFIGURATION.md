# LifeSaver Configuration Guide

## App Identity

Current Android package/application ID:

```text
com.rydertechnologies.medimap
```

Use matching IDs for Firebase Android apps, Google Cloud Android key restrictions, and release signing.

## Firebase

LifeSaver uses Firebase for:

- Firestore cloud hospital updates and report/admin workflows.
- Analytics.
- Crashlytics.
- Admin authentication checks.

Firestore rules are in:

```text
firestore.rules
```

Deploy rules:

```powershell
firebase deploy --only firestore:rules
```

## Admin Access

Admin access should be controlled with Firebase custom claims. Normal Firebase users should not become admins unless the backend/admin script sets an admin claim for that user.

The UI copy now says:

```text
Admin users must have the Firebase admin custom claim.
```

Keep admin emails out of production client code and rules. Client-side checks are only UX; Firestore rules and backend claims must enforce real access.

## Google Maps API Keys

Use separate keys for Android and Web.

### Android Key

Restrict by:

- Package name: `com.rydertechnologies.medimap`
- SHA-1 certificate fingerprint for the signing certificate
- Required APIs only, especially Maps SDK for Android

### Web Key

Restrict by HTTP referrer:

```text
https://app.life-saver.com.ng/*
```

For local testing, add the local port being used:

```text
http://localhost:8081/*
```

If using another local port, add that exact port too.

## Web Maps Config

The web key must not be committed directly into `web/index.html`.

The project uses:

```text
web/maps_loader.js
web/maps_config.example.js
web/maps_config.js
```

`web/maps_config.js` is ignored by git and should contain the actual local/deployment web key.

Example:

```js
window.LIFESAVER_GOOGLE_MAPS_API_KEY = "YOUR_WEB_MAPS_KEY";
```

## Release Signing

Android release signing depends on:

```text
android/key.properties
android/app/upload-keystore.jks
```

These should stay outside git. Keep secure backups of the keystore and passwords.
