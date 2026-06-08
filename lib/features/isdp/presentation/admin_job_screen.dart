import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class AdminJobScreen extends StatelessWidget {
  const AdminJobScreen({
    super.key,
    required this.order,
    required this.onSendQr,
    required this.onClose,
  });

  final WorkOrder order;
  final VoidCallback onSendQr;
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
                    InfoChip(icon: Icons.schedule_outlined, label: order.sla),
                    InfoChip(
                      icon: Icons.supervisor_account_outlined,
                      label: order.supervisor ?? 'No supervisor',
                    ),
                    InfoChip(
                      icon: Icons.person_outline,
                      label: order.assignedTo ?? 'No technician',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
        ),
        _AdminEvidenceCard(
          title: 'After photo',
          detail: 'Photo captured after work was completed.',
          complete: hasAfter,
        ),
      ],
    );
  }
}

class _AdminEvidenceCard extends StatelessWidget {
  const _AdminEvidenceCard({
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
