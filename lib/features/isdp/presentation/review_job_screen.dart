import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class ReviewJobScreen extends StatelessWidget {
  const ReviewJobScreen({
    super.key,
    required this.order,
    required this.onApprove,
    required this.onClose,
  });

  final WorkOrder order;
  final VoidCallback onApprove;
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.site,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  order.address,
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                Text(order.scope),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoChip(icon: Icons.badge_outlined, label: order.id),
                    InfoChip(
                      icon: Icons.person_outline,
                      label: order.assignedTo ?? 'No technician',
                    ),
                    InfoChip(icon: Icons.schedule_outlined, label: order.sla),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SectionTitle('Evidence'),
        const SizedBox(height: 10),
        _EvidenceReviewCard(
          title: 'Before photo',
          detail: 'Photo captured before work started.',
          complete: hasBefore,
        ),
        _EvidenceReviewCard(
          title: 'After photo',
          detail: 'Photo captured after work was completed.',
          complete: hasAfter,
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
        const SizedBox(height: 14),
        const SectionTitle('QR Test Value'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: SelectableText(order.siteCode)),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Copy QR value',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: order.siteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('QR test value copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: evidenceReady ? onApprove : null,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Approve Job'),
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
  });

  final String title;
  final String detail;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppTheme.success : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconPill(
                icon: complete
                    ? Icons.check_circle_outline
                    : Icons.image_not_supported_outlined,
                color: color,
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
                  ],
                ),
              ),
              StatusChip(label: complete ? 'Saved' : 'Missing', color: color),
            ],
          ),
        ),
      ),
    );
  }
}
