import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError('Firebase is configured only for Android. Configure iOS and web apps in project inkomati-usuthu-isdp before using those platforms.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB9CZ0JRM6ksBS-mHqx_7sgNTbeODWW8pk',
    appId: '1:486212138983:android:b0060d4286db27bfebaf42',
    messagingSenderId: '486212138983',
    projectId: 'inkomati-usuthu-isdp',
    storageBucket: 'inkomati-usuthu-isdp.firebasestorage.app',
  );
}
