import 'package:flutter/material.dart';

import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/auth_gate.dart';
import 'theme/app_theme.dart';

class IsdpApp extends StatelessWidget {
  const IsdpApp({super.key, this.home, this.authRepository});

  final Widget? home;
  final AuthRepository? authRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PHEPHA MV ISDP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home:
          home ??
          AuthGate(authRepository: authRepository ?? FirebaseAuthRepository()),
    );
  }
}
