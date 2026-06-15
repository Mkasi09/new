# PHEPHA MV ISDP Admin Desktop

Separate Flutter desktop project for the PHEPHA MV ISDP admin console.

This app is built for desktop and talks to the existing Firebase project through
Firebase REST APIs, so Windows can sign in and manage the same `work_orders`
collection used by the field app.

## Features

- Email/password admin sign-in
- Live refresh and 30-second polling of Firestore work orders
- Create work orders
- Search and filter work orders
- Open job detail view
- Accept, dispatch, mark onsite, submit, review, and approve jobs
- Technician assignment
- Material reconciliation view
- Acceptance and billing readiness queue
- Company and per-person analytics

## Run

```sh
flutter pub get
flutter run -d windows
```

## Verify

```sh
flutter analyze
flutter test
```
