import 'package:flutter/material.dart';

import '../../../core/domain/app_role.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/demo_people.dart';

class AccountView extends StatelessWidget {
  const AccountView({
    super.key,
    required this.role,
    required this.demoPerson,
    required this.availablePeople,
    required this.onRoleChanged,
    required this.onDemoPersonChanged,
    this.authRepository,
  });

  final AppRole role;
  final DemoPerson demoPerson;
  final List<DemoPerson> availablePeople;
  final ValueChanged<AppRole> onRoleChanged;
  final ValueChanged<DemoPerson> onDemoPersonChanged;
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
                            const Text(
                              'Commit ISDP',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Signed in as ${demoPerson.name} - ${role.label}',
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Demo Role',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: DropdownButtonFormField<AppRole>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.badge_outlined),
                          labelText: 'Current role',
                        ),
                        items: AppRole.values
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(role.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) onRoleChanged(value);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: DropdownButtonFormField<DemoPerson>(
                        initialValue: demoPerson,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_search_outlined),
                          labelText: 'Demo user',
                        ),
                        items: availablePeople
                            .map(
                              (person) => DropdownMenuItem(
                                value: person,
                                child: Text(person.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) onDemoPersonChanged(value);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    _AccountTile(
                      Icons.person_pin_circle_outlined,
                      'User',
                      demoPerson.name,
                    ),
                    const Divider(height: 1),
                    _AccountTile(
                      Icons.groups_outlined,
                      'Team',
                      demoPerson.team,
                    ),
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
