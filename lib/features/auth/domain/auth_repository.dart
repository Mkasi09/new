import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/domain/app_role.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.team,
    this.mustChangePassword = false,
  });

  final String uid;
  final String email;
  final String name;
  final AppRole role;
  final String? team;
  final bool mustChangePassword;
}

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  Future<AppUserProfile> currentUserProfile();

  Future<void> signIn({required String email, required String password});

  Future<void> sendPasswordResetEmail(String email);

  Future<void> changePassword(String newPassword);

  Future<void> createUser({
    required String name,
    required String email,
    required String temporaryPassword,
    required AppRole role,
    String? team,
  });

  Future<void> signOut();
}
