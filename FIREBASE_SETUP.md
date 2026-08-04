# Firebase setup for a new company

This source tree contains no Firebase project credentials. Create a new Firebase
project owned by the company that will operate the app, then enable
Authentication (Email/Password), Firestore, Storage, Cloud Functions, and Cloud
Messaging as required.

Run the app with its new project values:

```sh
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

Deploy `firestore.rules`, `firestore.indexes.json`, `storage.rules`, and
`functions` only to that new project. The desktop admin app also needs
`FIREBASE_API_KEY` and `FIREBASE_PROJECT_ID` as dart defines.
