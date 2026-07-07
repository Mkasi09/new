import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'widgets/common.dart';

class MobileInvoiceReview extends StatelessWidget {
  const MobileInvoiceReview({
    super.key,
    required this.invoiceId,
    required this.data,
  });

  final String invoiceId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final number = data['number'] as String? ?? invoiceId;
    final customer = data['customerName'] as String? ?? 'Customer';
    final workOrderId = data['workOrderId'] as String? ?? 'Unknown job';
    final status = data['status'] as String? ?? 'draft';
    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (data['taxAmount'] as num?)?.toDouble() ?? 0;
    final total = (data['total'] as num?)?.toDouble() ?? subtotal + tax;
    final dueAt = (data['dueAt'] as Timestamp?)?.toDate();

    return Scaffold(
      appBar: AppBar(title: Text(number)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('Invoice Review')),
                StatusChip(
                  label: _titleCase(status),
                  color: status == 'paid' ? AppTheme.success : AppTheme.warning,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ReviewRow(label: 'Invoice', value: number),
                    _ReviewRow(label: 'Job', value: workOrderId),
                    _ReviewRow(label: 'Customer', value: customer),
                    _ReviewRow(
                      label: 'Email',
                      value: data['customerEmail'] as String? ?? 'Not provided',
                    ),
                    _ReviewRow(
                      label: 'Due',
                      value: dueAt == null
                          ? 'Not set'
                          : '${dueAt.day.toString().padLeft(2, '0')}/${dueAt.month.toString().padLeft(2, '0')}/${dueAt.year}',
                      last: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const SectionTitle('Line Items'),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No line items recorded.'),
                ),
              )
            else
              ...items.map((item) {
                final quantity = (item['quantity'] as num?)?.toDouble() ?? 1;
                final price = (item['unitPrice'] as num?)?.toDouble() ?? 0;
                return Card(
                  child: ListTile(
                    title: Text(item['description'] as String? ?? 'Service'),
                    subtitle: Text(
                      '${quantity.toStringAsFixed(0)} × ${_money(price)}',
                    ),
                    trailing: Text(
                      _money(quantity * price),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ReviewRow(label: 'Subtotal', value: _money(subtotal)),
                    _ReviewRow(label: 'VAT', value: _money(tax)),
                    _ReviewRow(
                      label: 'Total',
                      value: _money(total),
                      last: true,
                      strong: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.last = false,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool last;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppTheme.muted)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _money(num value) => 'R ${value.toStringAsFixed(2)}';

String _titleCase(String value) =>
    value.isEmpty ? 'Draft' : '${value[0].toUpperCase()}${value.substring(1)}';
