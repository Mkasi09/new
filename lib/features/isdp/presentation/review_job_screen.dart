import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';
import 'widgets/evidence_photo_thumbnail.dart';

class ReviewJobScreen extends StatelessWidget {
  const ReviewJobScreen({
    super.key,
    required this.order,
    required this.onApprove,
    required this.onDecline,
    required this.onClose,
  });

  final WorkOrder order;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasBefore = order.evidenceSlots.contains('before');
    final hasAfter = order.evidenceSlots.contains('after');
    final evidenceReady = hasBefore && hasAfter;

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
            const Expanded(child: SectionTitle('Review Job')),
            StatusChip(
              label: order.reviewed ? 'Reviewed' : 'Needs review',
              color: order.reviewed ? AppTheme.success : AppTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: 12),
        JobOverviewPanel(order: order),
        const SizedBox(height: 14),
        WorkDurationPanel(order: order),
        const SizedBox(height: 14),
        const SectionTitle('Evidence'),
        const SizedBox(height: 10),
        _EvidenceReviewCard(
          title: 'Before photo',
          detail: 'Photo captured before work started.',
          complete: hasBefore,
          photoData: order.evidencePhotos['before'],
        ),
        _EvidenceReviewCard(
          title: 'After photo',
          detail: 'Photo captured after work was completed.',
          complete: hasAfter,
          photoData: order.evidencePhotos['after'],
        ),
        if (!evidenceReady) ...[
          const SizedBox(height: 4),
          const Text(
            'Before and after evidence are required before approval.',
            style: TextStyle(
              color: AppTheme.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDecline,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: evidenceReady ? onApprove : null,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Approve Job'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EvidenceReviewCard extends StatelessWidget {
  const _EvidenceReviewCard({
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
