import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/evidence_photo_thumbnail.dart';
import 'widgets/form_scaffold.dart';

class UploadEvidenceScreen extends StatefulWidget {
  const UploadEvidenceScreen({
    super.key,
    required this.order,
    this.onCompleted,
    this.onCancel,
  });

  final WorkOrder order;
  final void Function(List<String>, Map<String, String>)? onCompleted;
  final VoidCallback? onCancel;

  @override
  State<UploadEvidenceScreen> createState() => _UploadEvidenceScreenState();
}

class _UploadEvidenceScreenState extends State<UploadEvidenceScreen> {
  static const _maxPhotoBytes = 300000;
  final Set<String> _uploadedSlots = {};
  final Map<String, String> _photoDataBySlot = {};
  final ImagePicker _picker = ImagePicker();

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
    _photoDataBySlot.addAll(widget.order.evidencePhotos);
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._slots.map(
                      (slot) => _PhotoUploadTile(
                        slot: slot,
                        uploaded: _uploadedSlots.contains(slot.keyName),
                        photoData: _photoDataBySlot[slot.keyName],
                        onUpload: () => _pickPhoto(slot.keyName),
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

  Future<void> _pickPhoto(String slot) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 60,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This photo is too large. Choose a smaller image or use the camera.',
          ),
        ),
      );
      return;
    }
    final mimeType = image.mimeType ?? 'image/jpeg';
    final photoData = 'data:$mimeType;base64,${base64Encode(bytes)}';
    if (!mounted) return;

    setState(() {
      _uploadedSlots.add(slot);
      _photoDataBySlot[slot] = photoData;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Photo added.')));
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
      onCompleted(slots, Map.unmodifiable(_photoDataBySlot));
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
    required this.photoData,
    required this.onUpload,
  });

  final _PhotoSlot slot;
  final bool uploaded;
  final String? photoData;
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
            clipBehavior: Clip.antiAlias,
            child: photoData != null
                ? EvidencePhotoThumbnail(
                    photoData: photoData,
                    complete: uploaded,
                    size: 46,
                  )
                : Icon(uploaded ? Icons.image : slot.icon, color: color),
          ),
          title: Text(
            slot.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            uploaded ? 'Uploaded: ${slot.keyName}_photo.jpg' : slot.detail,
          ),
          trailing: uploaded
              ? IconButton.filledTonal(
                  tooltip: 'Replace photo',
                  onPressed: onUpload,
                  icon: const Icon(Icons.swap_horiz),
                )
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
