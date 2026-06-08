import 'package:flutter/material.dart';

import '../../../core/widgets/splash_screen.dart';
import '../../isdp/data/firebase_isdp_repository.dart';
import '../../isdp/presentation/isdp_shell.dart';
import '../domain/auth_repository.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: authRepository.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.data == null) {
          return LoginScreen(authRepository: authRepository);
        }

        return FutureBuilder(
          future: authRepository.currentUserRole(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            return IsdpShell(
              initialRole: roleSnapshot.data,
              authRepository: authRepository,
              isdpRepository: FirebaseIsdpRepository(),
            );
          },
        );
      },
    );
  }
}
