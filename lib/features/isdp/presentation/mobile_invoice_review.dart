import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../app/theme/app_theme.dart';
import 'widgets/common.dart';

class MobileInvoiceReview extends StatefulWidget {
  const MobileInvoiceReview({
    super.key,
    required this.invoiceId,
    required this.data,
  });

  final String invoiceId;
  final Map<String, dynamic> data;

  @override
  State<MobileInvoiceReview> createState() => _MobileInvoiceReviewState();
}

class _MobileInvoiceReviewState extends State<MobileInvoiceReview> {
  late Map<String, dynamic> _data = Map.of(widget.data);
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final invoiceId = widget.invoiceId;
    final data = _data;
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
    final pdfBytes = _buildInvoicePdf(invoiceId: invoiceId, data: data);

    return Scaffold(
      appBar: AppBar(
        title: Text(number),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            onPressed: () => _downloadPdf(context, number, pdfBytes),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
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
            const SizedBox(height: 14),
            _InvoiceActions(
              status: status,
              busy: _updating,
              onEdit: status == 'draft' ? _editDraft : null,
              onIssue: status == 'draft' ? _issueInvoice : null,
              onShare: () => _downloadPdf(context, number, pdfBytes),
              onPaid: status == 'issued' ? _markPaid : null,
              onVoid: status != 'paid' && status != 'voided'
                  ? _voidInvoice
                  : null,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: SectionTitle('Invoice Document')),
                FilledButton.icon(
                  onPressed: () => _downloadPdf(context, number, pdfBytes),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 620,
                child: PdfPreview(
                  build: (_) => pdfBytes,
                  useActions: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  maxPageWidth: 700,
                  pdfFileName: '${_safeFileName(number)}_invoice.pdf',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateInvoice(
    Map<String, Object?> changes,
    String message,
  ) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(widget.invoiceId)
          .update({...changes, 'updatedAt': FieldValue.serverTimestamp()});
      if (!mounted) return;
      setState(() {
        _data = {..._data, ...changes};
        _updating = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoice update failed: $error')));
    }
  }

  Future<void> _issueInvoice() async {
    final email = (_data['customerEmail'] as String? ?? '').trim();
    final total = (_data['total'] as num?)?.toDouble() ?? 0;
    final items = _data['items'] as List<dynamic>? ?? const [];
    if (email.isEmpty || total <= 0 || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a customer email and valid line item before issuing.',
          ),
        ),
      );
      return;
    }
    await _updateInvoice({
      'status': 'issued',
      'issuedAt': FieldValue.serverTimestamp(),
    }, 'Invoice issued.');
  }

  Future<void> _markPaid() => _updateInvoice({
    'status': 'paid',
    'paidAt': FieldValue.serverTimestamp(),
  }, 'Invoice marked as paid.');

  Future<void> _voidInvoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void invoice?'),
        content: const Text(
          'The invoice remains in the audit history but will no longer be collectible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void Invoice'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateInvoice({'status': 'voided'}, 'Invoice voided.');
    }
  }

  Future<void> _editDraft() async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => _InvoiceEditDialog(data: _data),
    );
    if (result != null) await _updateInvoice(result, 'Draft invoice updated.');
  }
}

class _InvoiceActions extends StatelessWidget {
  const _InvoiceActions({
    required this.status,
    required this.busy,
    required this.onEdit,
    required this.onIssue,
    required this.onShare,
    required this.onPaid,
    required this.onVoid,
  });

  final String status;
  final bool busy;
  final VoidCallback? onEdit;
  final VoidCallback? onIssue;
  final VoidCallback onShare;
  final VoidCallback? onPaid;
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Invoice Actions'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (onEdit != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Draft'),
                  ),
                if (onIssue != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onIssue,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Issue Invoice'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onShare,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share / Email'),
                ),
                if (onPaid != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onPaid,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Mark Paid'),
                  ),
                if (onVoid != null)
                  TextButton.icon(
                    onPressed: busy ? null : onVoid,
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Void'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceEditDialog extends StatefulWidget {
  const _InvoiceEditDialog({required this.data});
  final Map<String, dynamic> data;

  @override
  State<_InvoiceEditDialog> createState() => _InvoiceEditDialogState();
}

class _InvoiceEditDialogState extends State<_InvoiceEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customer;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final items = widget.data['items'] as List<dynamic>? ?? const [];
    final item = items.isEmpty
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(items.first as Map);
    _customer = TextEditingController(
      text: widget.data['customerName'] as String? ?? '',
    );
    _email = TextEditingController(
      text: widget.data['customerEmail'] as String? ?? '',
    );
    _address = TextEditingController(
      text: widget.data['customerAddress'] as String? ?? '',
    );
    _description = TextEditingController(
      text: item['description'] as String? ?? '',
    );
    _amount = TextEditingController(
      text:
          ((item['unitPrice'] as num?) ?? widget.data['subtotal'] as num? ?? 0)
              .toStringAsFixed(2),
    );
    _notes = TextEditingController(text: widget.data['notes'] as String? ?? '');
  }

  @override
  void dispose() {
    _customer.dispose();
    _email.dispose();
    _address.dispose();
    _description.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Draft Invoice'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_customer, 'Customer name'),
              _field(_email, 'Customer email'),
              _field(_address, 'Billing address', required: false),
              _field(_description, 'Description'),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount before VAT (R)',
                ),
                validator: (value) => (double.tryParse(value ?? '') ?? 0) > 0
                    ? null
                    : 'Enter a valid amount.',
              ),
              _field(_notes, 'Notes', required: false),
            ].expand((item) => [item, const SizedBox(height: 10)]).toList(),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save Changes')),
    ],
  );

  TextFormField _field(
    TextEditingController controller,
    String label, {
    bool required = true,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    validator: required
        ? (value) => value?.trim().isNotEmpty == true ? null : 'Required'
        : null,
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final subtotal = double.parse(_amount.text.trim());
    final taxRate = (widget.data['taxRate'] as num?)?.toDouble() ?? 0.15;
    Navigator.pop(context, <String, Object?>{
      'customerName': _customer.text.trim(),
      'customerEmail': _email.text.trim(),
      'customerAddress': _address.text.trim(),
      'items': [
        {
          'description': _description.text.trim(),
          'quantity': 1.0,
          'unitPrice': subtotal,
        },
      ],
      'subtotal': subtotal,
      'taxAmount': subtotal * taxRate,
      'total': subtotal * (1 + taxRate),
      'notes': _notes.text.trim(),
    });
  }
}

Future<void> _downloadPdf(
  BuildContext context,
  String invoiceNumber,
  Future<Uint8List> pdfBytes,
) async {
  try {
    await Printing.sharePdf(
      bytes: await pdfBytes,
      filename: '${_safeFileName(invoiceNumber)}_invoice.pdf',
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The invoice PDF could not be downloaded.')),
    );
  }
}

Future<Uint8List> _buildInvoicePdf({
  required String invoiceId,
  required Map<String, dynamic> data,
}) async {
  final number = data['number'] as String? ?? invoiceId;
  final customer = data['customerName'] as String? ?? 'Customer';
  final email = data['customerEmail'] as String? ?? '';
  final address = data['customerAddress'] as String? ?? '';
  final workOrderId = data['workOrderId'] as String? ?? 'Unknown job';
  final status = data['status'] as String? ?? 'draft';
  final notes = data['notes'] as String? ?? '';
  final items = (data['items'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  final subtotal = (data['subtotal'] as num?)?.toDouble() ?? 0;
  final tax = (data['taxAmount'] as num?)?.toDouble() ?? 0;
  final total = (data['total'] as num?)?.toDouble() ?? subtotal + tax;
  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
  final dueAt = (data['dueAt'] as Timestamp?)?.toDate();
  final document = pw.Document(title: number, author: 'Field Service Platform');

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      build: (_) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Field Service Platform',
                  style: pw.TextStyle(
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Integrated Service Delivery Platform'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 25,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(number),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  color: PdfColors.blueGrey800,
                  child: pw.Text(
                    status.toUpperCase(),
                    style: const pw.TextStyle(color: PdfColors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Divider(color: PdfColors.blueGrey400),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfLabel('BILL TO'),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    customer,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  if (address.isNotEmpty) pw.Text(address),
                  if (email.isNotEmpty) pw.Text(email),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                children: [
                  _pdfDetail('Invoice date', _pdfDate(createdAt)),
                  _pdfDetail('Due date', _pdfDate(dueAt)),
                  _pdfDetail('Work order', workOrderId),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Table(
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: PdfColors.grey300),
            bottom: pw.BorderSide(color: PdfColors.grey400),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(5),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              children: [
                _pdfCell('Description', header: true),
                _pdfCell('Qty', header: true, right: true),
                _pdfCell('Rate', header: true, right: true),
                _pdfCell('Amount', header: true, right: true),
              ],
            ),
            for (final item in items)
              pw.TableRow(
                children: [
                  _pdfCell(item['description'] as String? ?? 'Service'),
                  _pdfCell(_quantity(item['quantity']), right: true),
                  _pdfCell(
                    _money((item['unitPrice'] as num?) ?? 0),
                    right: true,
                  ),
                  _pdfCell(
                    _money(
                      ((item['quantity'] as num?) ?? 1) *
                          ((item['unitPrice'] as num?) ?? 0),
                    ),
                    right: true,
                  ),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfLabel('PAYMENT DETAILS'),
                  pw.SizedBox(height: 6),
                  pw.Text('Use $number as the payment reference.'),
                  if (notes.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    _pdfLabel('NOTES'),
                    pw.SizedBox(height: 6),
                    pw.Text(notes.trim()),
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 30),
            pw.SizedBox(
              width: 190,
              child: pw.Column(
                children: [
                  _pdfDetail('Subtotal', _money(subtotal)),
                  _pdfDetail('VAT', _money(tax)),
                  pw.Divider(),
                  _pdfDetail('TOTAL', _money(total), strong: true),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 30),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          color: PdfColors.grey100,
          child: pw.Text(
            'Thank you. Please quote the invoice number on all payment correspondence.',
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    ),
  );
  return document.save();
}

pw.Widget _pdfLabel(String value) => pw.Text(
  value,
  style: pw.TextStyle(
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.blueGrey700,
  ),
);

pw.Widget _pdfDetail(String label, String value, {bool strong = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.SizedBox(width: 12),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: strong ? 13 : 10,
            ),
          ),
        ],
      ),
    );

pw.Widget _pdfCell(String value, {bool header = false, bool right = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      child: pw.Text(
        value,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: header ? PdfColors.white : PdfColors.black,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

String _pdfDate(DateTime? value) => value == null
    ? 'Not set'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _quantity(Object? value) {
  final quantity = (value as num?)?.toDouble() ?? 1;
  return quantity == quantity.roundToDouble()
      ? quantity.toStringAsFixed(0)
      : quantity.toStringAsFixed(2);
}

String _safeFileName(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

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
