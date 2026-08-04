# Release checklist

## Completed

- Merge conflicts removed.
- Mobile analysis and tests pass.
- Android debug APK builds.
- Android release compilation and App Bundle packaging pass with the production upload key.
- Windows admin analysis, tests, and release build pass.
- Set the final Android package and iOS bundle ID for the new company.
- Matching Firebase Android and iOS applications are registered.
- Firestore rules, indexes, Storage rules, and all Cloud Functions are deployed.
- Firestore and Storage access is restricted by role and work-order assignment.

## Required before distributing Android

- Securely back up `android/app/production-upload-keystore.jks` and
  `android/key.properties` outside this computer. Losing the upload key or its
  password can prevent future app updates.
- Keep both files private; they are ignored by Git.
- The upload certificate SHA-256 fingerprint is
  `8D:5E:F9:89:0A:EF:98:93:B8:2C:57:65:BE:57:77:9D:37:35:41:33:EE:B8:E1:71:DB:28:65:09:B2:72:7C:19`.

Build subsequent release bundles with:

```powershell
flutter build appbundle --release --no-pub
```

## Required before distributing iOS

- Open `ios/Runner.xcworkspace` on macOS with Xcode.
- Select the new company's Apple Developer team.
- Enable Push Notifications and Background Modes / Remote notifications.
- Confirm the App Store provisioning profile for the new bundle ID.
- Archive and validate through Xcode.

## Required before public or organization-wide rollout

- Run the 500-user staging load test in `load-test/README.md`.
- Complete a small pilot with each role on real Android, Huawei, and iOS devices.
- Verify notification delivery, evidence upload, QR scanning, offline recovery, invoices, and password reset.
- Configure Firebase/Google Cloud budget alerts.
- Prepare privacy policy, support details, screenshots, store descriptions, and data-safety declarations.
- Code-sign the Windows admin executable or installer with the company certificate.
- Consider enabling Firebase App Check after Play Integrity and Apple App Attest credentials are available.
