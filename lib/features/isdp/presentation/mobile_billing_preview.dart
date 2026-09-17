import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'mobile_invoice_creator.dart';
import 'mobile_invoice_review.dart';
import 'widgets/common.dart';

// Temporary feature switch: set to false to remove Mobile Billing from Admin.
const mobileBillingPreviewEnabled = true;

class MobileBillingPreview extends StatelessWidget {
  const MobileBillingPreview({
    super.key,
    required this.orders,
    required this.onClose,
    required this.onOpenJob,
  });

  final List<WorkOrder> orders;
  final VoidCallback onClose;
  final ValueChanged<WorkOrder> onOpenJob;

  @override
  Widget build(BuildContext context) {
    final billingReady = orders
        .where((order) => order.status == 'Approved')
        .toList();
    final awaitingApproval = orders
        .where((order) => order.status == 'Submitted')
        .length;
    final visibleReady = billingReady.take(5).toList();

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
            const Expanded(child: SectionTitle('Mobile Billing Preview')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: AppTheme.primary.withValues(alpha: 0.06),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, color: AppTheme.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create, edit, issue, share, download, record payment, and void invoices directly from mobile.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _BillingMetric(
                icon: Icons.receipt_long_outlined,
                value: '${billingReady.length}',
                label: 'Billing ready',
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BillingMetric(
                icon: Icons.rate_review_outlined,
                value: '$awaitingApproval',
                label: 'Awaiting approval',
                color: AppTheme.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Ready to Invoice'),
        const SizedBox(height: 10),
        if (visibleReady.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No approved jobs are ready for billing.'),
            ),
          )
        else
          ...visibleReady.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BillingReadyCard(
                order: order,
                onOpenJob: () => onOpenJob(order),
                onCreateInvoice: () => _createInvoice(context, order),
              ),
            ),
          ),
        if (billingReady.length > visibleReady.length)
          Text(
            '${billingReady.length - visibleReady.length} more billing-ready jobs are available on desktop.',
            style: const TextStyle(color: AppTheme.muted),
          ),
        const SizedBox(height: 18),
        const SectionTitle('All Invoices'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('invoices')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Invoices could not be loaded.'),
                ),
              );
            }
            final invoices = snapshot.data?.docs ?? const [];
            if (invoices.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No invoices created yet.'),
                ),
              );
            }
            return Column(
              children: invoices.map((invoice) {
                final data = invoice.data();
                final total = (data['total'] as num?)?.toDouble() ?? 0;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(data['number'] as String? ?? invoice.id),
                    subtitle: Text(
                      '${data['customerName'] as String? ?? 'Customer'} • ${data['status'] as String? ?? 'draft'}',
                    ),
                    trailing: Text('R ${total.toStringAsFixed(2)}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MobileInvoiceReview(
                          invoiceId: invoice.id,
                          data: data,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _createInvoice(BuildContext context, WorkOrder order) async {
    final number = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => MobileInvoiceCreator(order: order)),
    );
    if (!context.mounted || number == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$number saved as a draft.')));
  }
}

class _BillingReadyCard extends StatelessWidget {
  const _BillingReadyCard({
    required this.order,
    required this.onOpenJob,
    required this.onCreateInvoice,
  });

  final WorkOrder order;
  final VoidCallback onOpenJob;
  final VoidCallback onCreateInvoice;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            WorkOrderCard(order: order, onTap: onOpenJob),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreateInvoice,
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Create Draft Invoice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingMetric extends StatelessWidget {
  const _BillingMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}
