import 'package:flutter/material.dart';

import '../../../core/widgets/splash_screen.dart';
import '../../isdp/data/firebase_isdp_repository.dart';
import '../../isdp/presentation/isdp_shell.dart';
import '../domain/auth_repository.dart';
import 'change_password_screen.dart';
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

        return FutureBuilder<AppUserProfile>(
          future: authRepository.currentUserProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            if (profileSnapshot.hasError || profileSnapshot.data == null) {
              return _ProfileLoadError(authRepository: authRepository);
            }

            if (profileSnapshot.data!.mustChangePassword) {
              return ChangePasswordScreen(authRepository: authRepository);
            }

            return IsdpShell(
              initialRole: profileSnapshot.data!.role,
              userProfile: profileSnapshot.data,
              authRepository: authRepository,
              isdpRepository: FirebaseIsdpRepository(),
            );
          },
        );
      },
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'We could not load your user profile.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your connection or ask an administrator to verify your account record.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: authRepository.signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Back to Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
