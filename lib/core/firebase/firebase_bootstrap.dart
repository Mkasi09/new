import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      throw StateError(
        'Firebase is not configured. Add the new company Firebase values as '
        '--dart-define options before running the app.',
      );
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
