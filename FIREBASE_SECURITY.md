# Firebase Security Setup

LifeSaver uses two Firestore collections:

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

The rules accept:

- a Firebase Auth custom claim: `admin: true`

The app also accepts:

- a Firebase Auth custom claim: `admin: true`

Set admin claims only from a trusted server or the Firebase Admin SDK. Do not grant production admin access from client-side email allowlists.

## Deploy Rules

Run:

```powershell
firebase deploy --only firestore:rules
```
