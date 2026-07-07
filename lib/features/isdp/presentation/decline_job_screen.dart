import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';
import 'widgets/form_scaffold.dart';

typedef DeclineDecision = ({String reason, bool allowResubmission});

class DeclineJobScreen extends StatefulWidget {
  const DeclineJobScreen({
    super.key,
    required this.order,
    required this.onDecline,
    required this.onCancel,
  });

  final WorkOrder order;
  final ValueChanged<DeclineDecision> onDecline;
  final VoidCallback onCancel;

  @override
  State<DeclineJobScreen> createState() => _DeclineJobScreenState();
}

class _DeclineJobScreenState extends State<DeclineJobScreen> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
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
                      icon: Icons.cancel_outlined,
                      title: 'Decline Job',
                      subtitle:
                          'Give the technician a clear reason, then choose whether corrections are allowed.',
                    ),
                    const SizedBox(height: 14),
                    WorkOrderCard(order: widget.order),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _reasonController,
                      autofocus: true,
                      minLines: 5,
                      maxLines: 8,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Reason for declining',
                        hintText:
                            'Explain what is wrong and what must be corrected',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Decline & Close is final. The technician can read the reason but cannot resubmit.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: _canSubmit
                      ? () => _submit(allowResubmission: true)
                      : null,
                  child: const Text('Return for correction'),
                ),
                FilledButton(
                  onPressed: _canSubmit
                      ? () => _submit(allowResubmission: false)
                      : null,
                  child: const Text('Decline & Close'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool get _canSubmit => _reasonController.text.trim().isNotEmpty;

  void _submit({required bool allowResubmission}) {
    widget.onDecline((
      reason: _reasonController.text.trim(),
      allowResubmission: allowResubmission,
    ));
  }
}
