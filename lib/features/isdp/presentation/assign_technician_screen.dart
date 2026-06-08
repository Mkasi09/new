import 'package:flutter/material.dart';

import '../data/demo_people.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';
import 'widgets/form_scaffold.dart';

class AssignTechnicianScreen extends StatefulWidget {
  const AssignTechnicianScreen({
    super.key,
    required this.order,
    this.onAssigned,
    this.onCancel,
  });

  final WorkOrder order;
  final ValueChanged<String>? onAssigned;
  final VoidCallback? onCancel;

  @override
  State<AssignTechnicianScreen> createState() => _AssignTechnicianScreenState();
}

class _AssignTechnicianScreenState extends State<AssignTechnicianScreen> {
  late final TextEditingController _controller;
  String? _selectedTechnician;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.order.assignedTo ?? '');
    final assignedTo = widget.order.assignedTo;
    _selectedTechnician =
        demoTechnicians.any((technician) => technician.name == assignedTo)
        ? assignedTo
        : null;
  }

  @override
  void dispose() {
    _controller.dispose();
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
                      icon: Icons.person_add_alt,
                      title: 'Assign Technician',
                      subtitle:
                          'Choose the technician; saving dispatches the job to them.',
                    ),
                    const SizedBox(height: 14),
                    WorkOrderCard(order: widget.order, onTap: () {}),
                    const SizedBox(height: 4),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTechnician,
                              decoration: const InputDecoration(
                                labelText: 'Available technician',
                                prefixIcon: Icon(Icons.engineering_outlined),
                              ),
                              items: demoTechnicians
                                  .map(
                                    (technician) => DropdownMenuItem(
                                      value: technician.name,
                                      child: Text(
                                        '${technician.name} - ${technician.team}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedTechnician = value;
                                  _controller.text = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Technician name or email',
                                prefixIcon: Icon(Icons.person_add_alt),
                              ),
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
          primaryIcon: Icons.person_add_alt,
          primaryLabel: 'Assign Job',
          onPrimary: _submit,
          onCancel: widget.onCancel,
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Technician name or email is required.')),
      );
      return;
    }
    final onAssigned = widget.onAssigned;
    if (onAssigned != null) {
      onAssigned(value);
    } else {
      Navigator.pop(context, value);
    }
  }
}
