import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'widgets/common.dart';

class AcceptanceView extends StatelessWidget {
  const AcceptanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        const SectionTitle('Acceptance & Billing Readiness'),
        const SizedBox(height: 10),
        const _BillingGate(
          title: 'Site QR verified',
          detail: 'Technician arrival was confirmed by scanning the site QR.',
          complete: true,
        ),
        const _BillingGate(
          title: 'Material consumed/returned',
          detail: 'New RRU consumed, faulty unit return pending at logistics.',
          complete: false,
        ),
        const _BillingGate(
          title: 'Admin approval',
          detail: 'Admin reviews the submitted job before billing.',
          complete: false,
        ),
        const _BillingGate(
          title: 'Invoice support pack',
          detail: 'WO number, admin approval, BOM, photos, and signature.',
          complete: true,
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Risk',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No Admin approval means finance cannot safely invoice. Resolve material return before submitting final claim.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: 0.62,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BillingGate extends StatelessWidget {
  const _BillingGate({
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
        child: ListTile(
          leading: IconPill(
            icon: complete ? Icons.check_circle : Icons.pending_actions,
            color: color,
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(detail),
          trailing: StatusChip(
            label: complete ? 'Ready' : 'Hold',
            color: color,
          ),
        ),
      ),
    );
  }
}
