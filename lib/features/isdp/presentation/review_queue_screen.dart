import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class ReviewQueueScreen extends StatelessWidget {
  const ReviewQueueScreen({
    super.key,
    required this.orders,
    required this.onOpenReview,
    required this.onClose,
  });

  final List<WorkOrder> orders;
  final ValueChanged<WorkOrder> onOpenReview;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final submitted = orders
        .where((order) => order.status == 'Submitted')
        .toList();
    final unreviewed = submitted.where((order) => !order.reviewed).length;

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
            const Expanded(child: SectionTitle('Submitted Jobs')),
            StatusChip(
              label: '$unreviewed new',
              color: unreviewed > 0 ? AppTheme.danger : AppTheme.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (submitted.isEmpty)
          const _EmptyReviewQueue()
        else
          ...submitted.map(
            (order) => _ReviewQueueCard(
              order: order,
              onTap: () => onOpenReview(order),
            ),
          ),
      ],
    );
  }
}

class _ReviewQueueCard extends StatelessWidget {
  const _ReviewQueueCard({required this.order, required this.onTap});

  final WorkOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBefore = order.evidenceSlots.contains('before');
    final hasAfter = order.evidenceSlots.contains('after');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconPill(
                      icon: Icons.fact_check_outlined,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.site,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${order.id} - ${order.technicianLabel ?? 'No technician'}',
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: order.reviewed ? 'Reviewed' : 'Needs review',
                      color: order.reviewed
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoChip(
                      icon: hasBefore
                          ? Icons.check_circle_outline
                          : Icons.image_not_supported_outlined,
                      label: hasBefore ? 'Before saved' : 'Before missing',
                    ),
                    InfoChip(
                      icon: hasAfter
                          ? Icons.check_circle_outline
                          : Icons.image_not_supported_outlined,
                      label: hasAfter ? 'After saved' : 'After missing',
                    ),
                    InfoChip(icon: Icons.schedule_outlined, label: order.sla),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyReviewQueue extends StatelessWidget {
  const _EmptyReviewQueue();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            IconPill(icon: Icons.verified_outlined, color: AppTheme.success),
            SizedBox(width: 12),
            Expanded(child: Text('No submitted jobs are waiting for review.')),
          ],
        ),
      ),
    );
  }
}
