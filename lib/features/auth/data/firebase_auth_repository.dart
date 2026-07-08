import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/domain/app_role.dart';
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'africa-south1');

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  @override
  Future<AppUserProfile> currentUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user is available.');
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? const <String, dynamic>{};
    final email = (data['email'] as String?)?.trim().isNotEmpty == true
        ? (data['email'] as String).trim()
        : user.email ?? '';
    final storedName = (data['name'] as String?)?.trim();
    final displayName = user.displayName?.trim();

    return AppUserProfile(
      uid: user.uid,
      email: email,
      name: storedName?.isNotEmpty == true
          ? storedName!
          : displayName?.isNotEmpty == true
          ? displayName!
          : _nameFromEmail(email),
      role: AppRole.fromString(data['role'] as String?),
      team: (data['team'] as String?)?.trim(),
      mustChangePassword: data['mustChangePassword'] as bool? ?? false,
    );
  }

  @override
  Future<List<AppUserProfile>> listUsers() async {
    final snapshot = await _firestore.collection('users').get();
    final users = snapshot.docs.map((doc) {
      final data = doc.data();
      final email = (data['email'] as String?)?.trim() ?? '';
      final name = (data['name'] as String?)?.trim();

      return AppUserProfile(
        uid: doc.id,
        email: email,
        name: name?.isNotEmpty == true ? name! : _nameFromEmail(email),
        role: AppRole.fromString(data['role'] as String?),
        team: (data['team'] as String?)?.trim(),
        mustChangePassword: data['mustChangePassword'] as bool? ?? false,
      );
    }).toList();

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No authenticated user is available.');

    await user.updatePassword(newPassword);
    await _firestore.collection('users').doc(user.uid).update({
      'mustChangePassword': false,
      'passwordChangedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> changePasswordWithCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw StateError('No authenticated user is available.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await changePassword(newPassword);
  }

  @override
  Future<void> createUser({
    required String name,
    required String email,
    required String temporaryPassword,
    required AppRole role,
    String? team,
  }) async {
    await _functions.httpsCallable('createUser').call(<String, Object?>{
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'temporaryPassword': temporaryPassword,
      'role': role.name,
      'team': team?.trim(),
    });
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  String _nameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return 'ISDP User';
    return localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
