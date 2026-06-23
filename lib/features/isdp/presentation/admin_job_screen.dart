import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';
import 'widgets/evidence_photo_thumbnail.dart';

class AdminJobScreen extends StatelessWidget {
  const AdminJobScreen({
    super.key,
    required this.order,
    required this.onSendQr,
    required this.onDelete,
    required this.onClose,
  });

  final WorkOrder order;
  final VoidCallback onSendQr;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasBefore = order.evidenceSlots.contains('before');
    final hasAfter = order.evidenceSlots.contains('after');

    return AppScrollView(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            const Expanded(child: SectionTitle('Job Details')),
            StatusChip(
              label: order.status,
              color: workOrderStatusColor(order.status),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<_AdminJobOption>(
              tooltip: 'Options',
              onSelected: (option) {
                switch (option) {
                  case _AdminJobOption.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AdminJobOption.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppTheme.danger),
                      SizedBox(width: 10),
                      Text('Delete job'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        JobOverviewPanel(order: order),
        const SizedBox(height: 14),
        WorkDurationPanel(order: order),
        const SizedBox(height: 14),
        const SectionTitle('QR Code'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Site QR PDF',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Generate an external PDF with a scannable QR code for this job.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onSendQr,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Generate QR PDF'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SectionTitle('Evidence'),
        const SizedBox(height: 10),
        _AdminEvidenceCard(
          title: 'Before photo',
          detail: 'Photo captured before work started.',
          complete: hasBefore,
          photoData: order.evidencePhotos['before'],
        ),
        _AdminEvidenceCard(
          title: 'After photo',
          detail: 'Photo captured after work was completed.',
          complete: hasAfter,
          photoData: order.evidencePhotos['after'],
        ),
      ],
    );
  }
}

enum _AdminJobOption { delete }

class _AdminEvidenceCard extends StatelessWidget {
  const _AdminEvidenceCard({
    required this.title,
    required this.detail,
    required this.complete,
    required this.photoData,
  });

  final String title;
  final String detail;
  final bool complete;
  final String? photoData;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppTheme.success : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EvidencePhotoViewer(
                photoData: photoData,
                complete: complete,
                title: title,
                size: 92,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(detail, style: const TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        label: complete ? 'Photo visible' : 'Missing',
                        color: color,
                      ),
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
