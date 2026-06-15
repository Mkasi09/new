import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.order.assignedTo ?? '');
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
                    WorkOrderCard(order: widget.order),
                    const SizedBox(height: 4),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Technician email',
                                hintText: 'name@company.com',
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
    if (value.isEmpty || !value.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid technician email.')),
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
