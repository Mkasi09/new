import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isdp_admin_desktop/main.dart';

void main() {
  testWidgets('invoice PDF is generated for visual verification', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 6, 30);
    final invoice = Invoice(
      id: 'invoice-preview',
      number: 'INV-2026-00125',
      workOrderId: 'JOB-CMT-ESW-101',
      customerName: 'Ezulwini Telecommunications (Pty) Ltd',
      customerEmail: 'accounts@ezulwini.example',
      customerAddress: '14 Valley Road, Ezulwini, Eswatini',
      items: const [
        InvoiceLineItem(
          description: 'Router installation and site commissioning',
          quantity: 1,
          unitPrice: 1800,
        ),
        InvoiceLineItem(
          description: 'Additional network testing',
          quantity: 2,
          unitPrice: 450,
        ),
      ],
      taxRate: 0.15,
      status: InvoiceStatus.issued,
      createdAt: now,
      dueAt: now.add(const Duration(days: 30)),
      issuedAt: now,
      createdBy: 'admin-preview',
      notes: 'Payment terms: 30 days from invoice date.',
    );
    final order = WorkOrder(
      id: invoice.workOrderId,
      site: 'Ezulwini Central Exchange',
      address: '14 Valley Road, Ezulwini',
      scope: 'Router installation and site commissioning',
      sla: 'Approved',
      siteCode: 'SITE-101',
      status: 'Approved',
      priority: Priority.high,
    );

    final bytes = await buildInvoicePdfBytes(invoice, order);
    expect(bytes.take(4).toList(), [0x25, 0x50, 0x44, 0x46]);

    final output = Directory('output/pdf')..createSync(recursive: true);
    final file = File('${output.path}/invoice_preview.pdf');
    file.writeAsBytesSync(bytes, flush: true);
    expect(file.lengthSync(), greaterThan(1000));
  });
}
