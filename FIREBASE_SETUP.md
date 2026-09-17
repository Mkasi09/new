# Firebase setup for INKOMATI-USUTHU ISDP

The Firebase target is `inkomati-usuthu-isdp` in `.firebaserc`. The old project's app keys and native configuration files were intentionally not copied. The new Firebase project must have Android, iOS, and web apps registered before the main Flutter app can start.

1. Sign in with an account that can manage `inkomati-usuthu-isdp`.
2. Register Android package `za.co.inkomatiusuthu.isdp` and iOS bundle ID `za.co.inkomatiusuthu.isdp` in that project. Register a web app as well.
3. Run `flutterfire configure --project=inkomati-usuthu-isdp --platforms=android,ios,web --android-package-name=za.co.inkomatiusuthu.isdp --ios-bundle-id=za.co.inkomatiusuthu.isdp`. This replaces the temporary `lib/firebase_options.dart` guard and supplies the new native config files.
4. For the admin desktop app, provide the new web app's API key at build or run time with `--dart-define=FIREBASE_WEB_API_KEY=...`.
5. Review Authentication, Firestore, Storage, Functions, and Messaging setup in the new project before use. Data from the old project was not copied.
