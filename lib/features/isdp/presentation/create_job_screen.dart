import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../domain/entities.dart';
import 'widgets/form_scaffold.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({
    super.key,
    this.supervisors = const [],
    this.onCreated,
    this.onCancel,
  });

  final List<AppUserProfile> supervisors;
  final Future<void> Function(WorkOrder)? onCreated;
  final VoidCallback? onCancel;

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _siteController = TextEditingController();
  final _addressController = TextEditingController();
  final _scopeController = TextEditingController();
  late DateTime _dueAt = DateTime.now().add(const Duration(days: 1));
  late final int _draftNumber = DateTime.now().microsecondsSinceEpoch;
  Priority _priority = Priority.high;
  AppUserProfile? _supervisor;
  bool _creating = false;

  @override
  void dispose() {
    _siteController.dispose();
    _addressController.dispose();
    _scopeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      icon: Icons.add_task,
                      title: 'New Job',
                      subtitle:
                          'Capture the job details. QR routing and supervisor assignment run automatically.',
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _siteController,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Site name',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _addressController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Address',
                                prefixIcon: Icon(Icons.map_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _scopeController,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Work scope',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(Icons.build_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickDueDate,
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    label: Text(_dateLabel(_dueAt)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickDueTime,
                                    icon: const Icon(Icons.schedule_outlined),
                                    label: Text(_timeLabel(_dueAt)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Priority>(
                              initialValue: _priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                prefixIcon: Icon(Icons.flag_outlined),
                              ),
                              items: Priority.values
                                  .map(
                                    (priority) => DropdownMenuItem(
                                      value: priority,
                                      child: Text(priority.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _priority = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _supervisor?.uid,
                              decoration: const InputDecoration(
                                labelText: 'Assign supervisor',
                                helperText:
                                    'Choose who must review and accept this job.',
                                prefixIcon: Icon(
                                  Icons.supervisor_account_outlined,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Shared supervisor queue'),
                                ),
                                ...widget.supervisors.map(
                                  (supervisor) => DropdownMenuItem<String>(
                                    value: supervisor.uid,
                                    child: Text(
                                      '${supervisor.name} (${supervisor.email})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (uid) {
                                setState(() {
                                  _supervisor = uid == null
                                      ? null
                                      : widget.supervisors.firstWhere(
                                          (user) => user.uid == uid,
                                        );
                                });
                              },
                            ),
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
          primaryIcon: Icons.add_task,
          primaryLabel: _creating ? 'Creating...' : 'Create Job',
          onPrimary: _creating ? null : _submit,
          onCancel: widget.onCancel,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_creating) return;
    final site = _siteController.text.trim();
    final address = _addressController.text.trim();
    final scope = _scopeController.text.trim();
    if (site.isEmpty || address.isEmpty || scope.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Site name, address, and work scope are required.'),
        ),
      );
      return;
    }
    if (!_dueAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Due date and time must be in the future.'),
        ),
      );
      return;
    }

    final order = WorkOrder(
      id: 'JOB-CMT-ESW-$_draftNumber',
      site: site,
      address: address,
      scope: scope,
      sla: _dueText(_dueAt),
      siteCode: 'SITE-$_draftNumber',
      status: 'Assigned to Supervisor',
      priority: _priority,
      dueAt: _dueAt,
      supervisor: _supervisor?.name,
      supervisorId: _supervisor?.uid,
    );
    final onCreated = widget.onCreated;
    if (onCreated != null) {
      setState(() => _creating = true);
      try {
        await onCreated(order);
      } finally {
        if (mounted) setState(() => _creating = false);
      }
    } else {
      Navigator.pop(context, order);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
      _dueAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dueAt.hour,
        _dueAt.minute,
      );
    });
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (picked == null) return;

    setState(() {
      _dueAt = DateTime(
        _dueAt.year,
        _dueAt.month,
        _dueAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  String _dueText(DateTime dueAt) {
    final date = _dateLabel(dueAt);
    final time = _timeLabel(dueAt);
    return 'Due by $date at $time';
  }

  String _dateLabel(DateTime value) {
    return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
  }

  String _timeLabel(DateTime value) {
    return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
