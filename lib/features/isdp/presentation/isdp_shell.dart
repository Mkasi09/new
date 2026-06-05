import 'package:flutter/material.dart';

import '../../../core/domain/app_role.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/mock_isdp_repository.dart';
import '../domain/entities.dart';
import '../domain/isdp_repository.dart';
import 'dashboard_view.dart';
import 'work_orders_view.dart';

class IsdpShell extends StatefulWidget {
  const IsdpShell({
    super.key,
    this.initialRole,
    this.authRepository,
    this.isdpRepository,
  });

  final AppRole? initialRole;
  final AuthRepository? authRepository;
  final IsdpRepository? isdpRepository;

  @override
  State<IsdpShell> createState() => _IsdpShellState();
}

class _IsdpShellState extends State<IsdpShell> {
  int _tab = 0;
  late AppRole _role = widget.initialRole ?? AppRole.technician;
  late final IsdpRepository _repository =
      widget.isdpRepository ?? const MockIsdpRepository();
  late WorkOrder _selectedOrder = _repository.getWorkOrders().first;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardView(
        role: _role,
        selectedOrder: _selectedOrder,
        workOrders: _repository.getWorkOrders(),
        jobSteps: _repository.getJobSteps(),
        materials: _repository.getMaterials(),
        onOpenOrder: _openOrder,
      ),
      WorkOrdersView(
        role: _role,
        workOrders: _repository.getWorkOrders(),
        onOpenOrder: _openOrder,
      ),
      _AccountView(
        role: _role,
        onRoleChanged: (role) => setState(() => _role = role),
        authRepository: widget.authRepository,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 30),
            const SizedBox(width: 10),
            const Expanded(child: Text('Commit ISDP')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync',
            onPressed: () {},
            icon: const Icon(Icons.cloud_done_outlined),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  void _openOrder(WorkOrder order) {
    setState(() {
      _selectedOrder = order;
      _tab = 0;
    });
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView({
    required this.role,
    required this.onRoleChanged,
    this.authRepository,
  });

  final AppRole role;
  final ValueChanged<AppRole> onRoleChanged;
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
                              'Signed in as ${role.label}',
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
                    const Divider(height: 1),
                    const _AccountTile(
                      Icons.person_pin_circle_outlined,
                      'User',
                      'Sibusiso M.',
                    ),
                    const Divider(height: 1),
                    const _AccountTile(
                      Icons.groups_outlined,
                      'Team',
                      'Commit Eswatini',
                    ),
                    const Divider(height: 1),
                    const _AccountTile(
                      Icons.security_outlined,
                      'Role',
                      'Loaded from profile in production',
                    ),
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
