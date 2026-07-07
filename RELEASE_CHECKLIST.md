# Release checklist

## Completed

- Merge conflicts removed.
- Mobile analysis and tests pass.
- Android debug APK builds.
- Android release compilation and App Bundle packaging pass with a temporary test key.
- Windows admin analysis, tests, and release build pass.
- Final Android package and iOS bundle ID are `za.co.phephamv.isdp`.
- Matching Firebase Android and iOS applications are registered.
- Firestore rules, indexes, Storage rules, and all Cloud Functions are deployed.
- Firestore and Storage access is restricted by role and work-order assignment.

## Required before distributing Android

Create and securely back up a production upload keystore. Do not reuse the debug key used during build verification.

```powershell
& 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe' `
  -genkeypair -v `
  -keystore C:\dev\ISDP\android\app\upload-keystore.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/key.properties.example` to `android/key.properties`, replace both passwords, and then build:

```powershell
flutter build appbundle --release --no-pub
```

Both the keystore and `key.properties` are ignored by Git. Back up the keystore and passwords outside this computer.

## Required before distributing iOS

- Open `ios/Runner.xcworkspace` on macOS with Xcode.
- Select the PHEPHA MV Apple Developer team.
- Enable Push Notifications and Background Modes / Remote notifications.
- Confirm the App Store provisioning profile for `za.co.phephamv.isdp`.
- Archive and validate through Xcode.

## Required before public or organization-wide rollout

- Run the 500-user staging load test in `load-test/README.md`.
- Complete a small pilot with each role on real Android, Huawei, and iOS devices.
- Verify notification delivery, evidence upload, QR scanning, offline recovery, invoices, and password reset.
- Configure Firebase/Google Cloud budget alerts.
- Prepare privacy policy, support details, screenshots, store descriptions, and data-safety declarations.
- Code-sign the Windows admin executable or installer with the company certificate.
- Consider enabling Firebase App Check after Play Integrity and Apple App Attest credentials are available.
