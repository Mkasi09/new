import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app/isdp_app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/domain/app_role.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FirebaseBootstrap.initialize();
    runApp(const IsdpApp());
  } catch (_) {
    // Keep the presentation usable even while a Firebase project is being
    // configured. Sign-in is disabled until initialization succeeds.
    runApp(
      IsdpApp(home: LoginScreen(authRepository: _UnavailableAuthRepository())),
    );
  }
}

class _UnavailableAuthRepository implements AuthRepository {
  Never get _unavailable =>
      throw StateError('Sign-in is currently unavailable.');

  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> changePassword(String newPassword) async => _unavailable;

  @override
  Future<void> changePasswordWithCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async => _unavailable;

  @override
  Future<void> createUser({
    required String name,
    required String email,
    required String temporaryPassword,
    required AppRole role,
    String? team,
  }) async => _unavailable;

  @override
  Future<AppUserProfile> currentUserProfile() async => _unavailable;

  @override
  Future<List<AppUserProfile>> listUsers() async => _unavailable;

  @override
  Future<void> sendPasswordResetEmail(String email) async => _unavailable;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => _unavailable;

  @override
  Future<void> signOut() async {}
}
