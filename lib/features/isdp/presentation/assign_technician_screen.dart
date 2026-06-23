import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/domain/app_role.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';
import 'widgets/form_scaffold.dart';

class AssignTechnicianScreen extends StatefulWidget {
  const AssignTechnicianScreen({
    super.key,
    required this.order,
    this.technicians = const [],
    this.onAssigned,
    this.onCancel,
  });

  final WorkOrder order;
  final List<AppUserProfile> technicians;
  final ValueChanged<List<String>>? onAssigned;
  final VoidCallback? onCancel;

  @override
  State<AssignTechnicianScreen> createState() => _AssignTechnicianScreenState();
}

class _AssignTechnicianScreenState extends State<AssignTechnicianScreen> {
  late final TextEditingController _searchController;
  late final Set<String> _selectedNames;

  List<AppUserProfile> get _technicians => widget.technicians
      .where((user) => user.role == AppRole.technician)
      .toList();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedNames = {...widget.order.technicianNames};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _technicians
        : _technicians.where((technician) {
            return [
              technician.name,
              technician.email,
              technician.team ?? '',
            ].any((value) => value.toLowerCase().contains(query));
          }).toList();

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    const FormHeader(
                      icon: Icons.person_add_alt,
                      title: 'Assign Technicians',
                      subtitle:
                          'Search by name or email, then choose one or more technicians.',
                    ),
                    const SizedBox(height: 14),
                    WorkOrderCard(order: widget.order),
                    const SizedBox(height: 4),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Search technicians',
                                hintText: 'Name or email',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedNames.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedNames
                                    .map(
                                      (name) => InputChip(
                                        avatar: const Icon(Icons.person),
                                        label: Text(name),
                                        onDeleted: () => setState(
                                          () => _selectedNames.remove(name),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_technicians.isEmpty)
                              const _EmptyTechnicianDirectory()
                            else if (filtered.isEmpty)
                              const _EmptySearchResult()
                            else
                              ...filtered.map(_technicianTile),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        FormActionBar(
          primaryIcon: Icons.person_add_alt,
          primaryLabel: _selectedNames.length == 1
              ? 'Assign Job'
              : 'Assign ${_selectedNames.length}',
          onPrimary: _submit,
          onCancel: widget.onCancel,
        ),
      ],
    );
  }

  Widget _technicianTile(AppUserProfile technician) {
    final selected = _selectedNames.contains(technician.name);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: selected,
      onChanged: (_) => setState(() {
        if (selected) {
          _selectedNames.remove(technician.name);
        } else {
          _selectedNames.add(technician.name);
        }
      }),
      secondary: CircleAvatar(
        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
        child: Text(
          technician.name.isEmpty ? '?' : technician.name[0].toUpperCase(),
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(
        technician.name,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: technician.team?.isNotEmpty == true
          ? Text(technician.team!)
          : const Text('Technician'),
    );
  }

  void _submit() {
    final allowedNames = _technicians
        .map((technician) => technician.name)
        .toSet();
    final names = _selectedNames.where(allowedNames.contains).toList()..sort();
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an existing technician.')),
      );
      return;
    }
    final onAssigned = widget.onAssigned;
    if (onAssigned != null) {
      onAssigned(names);
    } else {
      Navigator.pop(context, names);
    }
  }
}

class _EmptyTechnicianDirectory extends StatelessWidget {
  const _EmptyTechnicianDirectory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Text(
        'No technicians are available. Add technician users first.',
        style: TextStyle(color: AppTheme.muted),
      ),
    );
  }
}

class _EmptySearchResult extends StatelessWidget {
  const _EmptySearchResult();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Text(
        'No technicians match this search.',
        style: TextStyle(color: AppTheme.muted),
      ),
    );
  }
}
