import 'package:flutter/material.dart';

import '../../../core/domain/app_role.dart';
import '../../auth/domain/auth_repository.dart';

class AccountView extends StatelessWidget {
  const AccountView({
    super.key,
    required this.role,
    this.userProfile,
    this.authRepository,
  });

  final AppRole role;
  final AppUserProfile? userProfile;
  final AuthRepository? authRepository;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Image.asset('assets/logo1.png', height: 54),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(text: 'PHEPHA MV '),
                                  TextSpan(
                                    text: 'ISDP',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Signed in as ${userProfile?.name ?? role.label}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _AccountTile(
                      Icons.person_pin_circle_outlined,
                      'User',
                      userProfile?.name ?? 'Signed-in user',
                    ),
                    const Divider(height: 1),
                    _AccountTile(
                      Icons.email_outlined,
                      'Email',
                      userProfile?.email.isNotEmpty == true
                          ? userProfile!.email
                          : 'Not available',
                    ),
                    if (userProfile?.team?.isNotEmpty == true) ...[
                      const Divider(height: 1),
                      _AccountTile(
                        Icons.groups_outlined,
                        'Team',
                        userProfile!.team!,
                      ),
                    ],
                    const Divider(height: 1),
                    _AccountTile(Icons.security_outlined, 'Role', role.label),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign Out'),
                      onTap: authRepository?.signOut,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
