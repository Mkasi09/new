import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/domain/app_role.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  Future<AppRole> currentUserRole();

  Future<void> signIn({required String email, required String password});

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
