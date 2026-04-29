# Firebase Security Setup

MediMap uses two Firestore collections:

- `facility_reports`: reports submitted by normal app users.
- `hospital_updates`: approved hospital additions, corrections, and closures.

## Rules

Rules are in `firestore.rules` and are connected in `firebase.json`.

Normal users can:

- create `facility_reports`
- read only approved `hospital_updates`

Admins can:

- read/delete `facility_reports`
- create/update/delete `hospital_updates`

## Admin Access

The rules accept either:

- a Firebase Auth custom claim: `admin: true`
- an allowlisted admin email in `firestore.rules`

The app also accepts either:

- a Firebase Auth custom claim: `admin: true`
- an allowlisted admin email in `lib/main.dart`

Before production, keep only real admin emails in both files, or set a proper custom claim from a trusted server/Admin SDK.

## Deploy Rules

Run:

```powershell
firebase deploy --only firestore:rules
```
