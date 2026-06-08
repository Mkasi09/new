import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/form_scaffold.dart';

class UploadEvidenceScreen extends StatefulWidget {
  const UploadEvidenceScreen({
    super.key,
    required this.order,
    this.onCompleted,
    this.onCancel,
  });

  final WorkOrder order;
  final ValueChanged<List<String>>? onCompleted;
  final VoidCallback? onCancel;

  @override
  State<UploadEvidenceScreen> createState() => _UploadEvidenceScreenState();
}

class _UploadEvidenceScreenState extends State<UploadEvidenceScreen> {
  final Set<String> _uploadedSlots = {};

  static const _slots = [
    _PhotoSlot(
      keyName: 'before',
      title: 'Before photo',
      detail: 'Show the issue before work starts',
      icon: Icons.photo_camera_outlined,
    ),
    _PhotoSlot(
      keyName: 'after',
      title: 'After photo',
      detail: 'Show the completed repair or installation',
      icon: Icons.task_alt,
    ),
  ];

  bool get _complete => _uploadedSlots.length == _slots.length;
  bool get _canSave => _uploadedSlots.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _uploadedSlots.addAll(widget.order.evidenceSlots);
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
                    FormHeader(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Upload Images',
                      subtitle:
                          '${widget.order.site} - capture before and after photos.',
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _complete
                                  ? Icons.check_circle
                                  : Icons.pending_actions_outlined,
                              color: _complete
                                  ? AppTheme.success
                                  : AppTheme.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${_uploadedSlots.length}/${_slots.length} evidence photos saved',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _uploadAll,
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: const Text('Demo Fill'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._slots.map(
                      (slot) => _PhotoUploadTile(
                        slot: slot,
                        uploaded: _uploadedSlots.contains(slot.keyName),
                        onUpload: () => _upload(slot.keyName),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        FormActionBar(
          primaryIcon: Icons.check_circle_outline,
          primaryLabel: _complete ? 'Save Evidence' : 'Save Progress',
          onPrimary: _canSave ? _submit : _showMissing,
          onCancel: widget.onCancel,
        ),
      ],
    );
  }

  void _upload(String slot) {
    setState(() => _uploadedSlots.add(slot));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Demo image uploaded.')));
  }

  void _uploadAll() {
    setState(() => _uploadedSlots.addAll(_slots.map((slot) => slot.keyName)));
  }

  void _showMissing() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add at least one evidence photo first.')),
    );
  }

  void _submit() {
    final onCompleted = widget.onCompleted;
    final slots = _orderedUploadedSlots();
    if (onCompleted != null) {
      onCompleted(slots);
    } else {
      Navigator.pop(context, slots);
    }
  }

  List<String> _orderedUploadedSlots() {
    return _slots
        .where((slot) => _uploadedSlots.contains(slot.keyName))
        .map((slot) => slot.keyName)
        .toList();
  }
}

class _PhotoSlot {
  const _PhotoSlot({
    required this.keyName,
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String keyName;
  final String title;
  final String detail;
  final IconData icon;
}

class _PhotoUploadTile extends StatelessWidget {
  const _PhotoUploadTile({
    required this.slot,
    required this.uploaded,
    required this.onUpload,
  });

  final _PhotoSlot slot;
  final bool uploaded;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final color = uploaded ? AppTheme.success : AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(uploaded ? Icons.image : slot.icon, color: color),
          ),
          title: Text(
            slot.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            uploaded ? 'Uploaded: ${slot.keyName}_demo.jpg' : slot.detail,
          ),
          trailing: uploaded
              ? const Icon(Icons.check_circle, color: AppTheme.success)
              : FilledButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add'),
                ),
        ),
      ),
    );
  }
}
