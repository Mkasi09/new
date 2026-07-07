import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/entities.dart';
import 'widgets/common.dart';

class MobileInvoiceCreator extends StatefulWidget {
  const MobileInvoiceCreator({super.key, required this.order});

  final WorkOrder order;

  @override
  State<MobileInvoiceCreator> createState() => _MobileInvoiceCreatorState();
}

class _MobileInvoiceCreatorState extends State<MobileInvoiceCreator> {
  static const _taxRate = 0.15;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customer;
  late final TextEditingController _email;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _customer = TextEditingController(
      text: order.customerName?.trim().isNotEmpty == true
          ? order.customerName
          : order.site,
    );
    _email = TextEditingController();
    _description = TextEditingController(text: order.scope);
    _amount = TextEditingController(
      text: switch (order.priority) {
        Priority.critical => '2500.00',
        Priority.high => '1800.00',
        Priority.low => '1200.00',
      },
    );
  }

  @override
  void dispose() {
    _customer.dispose();
    _email.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = double.tryParse(_amount.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Draft Invoice')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              WorkOrderCard(order: widget.order),
              const SizedBox(height: 14),
              TextFormField(
                controller: _customer,
                decoration: const InputDecoration(labelText: 'Customer name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Customer email (optional for draft)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Amount before VAT (R)',
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0
                      ? 'Enter an amount greater than zero.'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Subtotal: R ${subtotal.toStringAsFixed(2)}'),
                      Text(
                        'VAT (15%): R ${(subtotal * _taxRate).toStringAsFixed(2)}',
                      ),
                      const Divider(),
                      Text(
                        'Total: R ${(subtotal * (1 + _taxRate)).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save Draft Invoice'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value?.trim().isNotEmpty == true ? null : 'This field is required.';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final invoices = FirebaseFirestore.instance.collection('invoices');
      final existing = await invoices
          .where('workOrderId', isEqualTo: widget.order.id)
          .limit(1)
          .get();
      final hasActiveInvoice = existing.docs.any(
        (document) => document.data()['status'] != 'voided',
      );
      if (hasActiveInvoice) {
        throw StateError('An invoice already exists for this job.');
      }
      final now = DateTime.now();
      final serial = now.millisecondsSinceEpoch.toString().substring(6);
      final number = 'INV-${now.year}-$serial';
      final subtotal = double.parse(_amount.text.trim());
      await invoices.doc('invoice-$serial').set({
        'number': number,
        'workOrderId': widget.order.id,
        'customerName': _customer.text.trim(),
        'customerEmail': _email.text.trim(),
        'customerAddress': widget.order.address,
        'items': [
          {
            'description': _description.text.trim(),
            'quantity': 1.0,
            'unitPrice': subtotal,
          },
        ],
        'taxRate': _taxRate,
        'subtotal': subtotal,
        'taxAmount': subtotal * _taxRate,
        'total': subtotal * (1 + _taxRate),
        'status': 'draft',
        'createdAt': FieldValue.serverTimestamp(),
        'dueAt': Timestamp.fromDate(now.add(const Duration(days: 30))),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'notes': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context, number);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save invoice: $error')));
    }
  }
}
