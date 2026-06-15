import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';
import 'widgets/common.dart';

class CompletionDetailsScreen extends StatefulWidget {
  const CompletionDetailsScreen({
    super.key,
    required this.order,
    required this.onSaved,
    required this.onCancel,
  });

  final WorkOrder order;
  final ValueChanged<WorkOrder> onSaved;
  final VoidCallback onCancel;

  @override
  State<CompletionDetailsScreen> createState() =>
      _CompletionDetailsScreenState();
}

class _CompletionDetailsScreenState extends State<CompletionDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late final TextEditingController _issueController;
  late final TextEditingController _customerController;
  late List<List<Offset>> _strokes;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.order.technicianNotes ?? '',
    );
    _issueController = TextEditingController(
      text: widget.order.issueReport ?? '',
    );
    _customerController = TextEditingController(
      text: widget.order.customerName ?? '',
    );
    _strokes = decodeSignature(widget.order.customerSignature);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _issueController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScrollView(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: widget.onCancel,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            const Expanded(child: SectionTitle('Job Completion')),
          ],
        ),
        const SizedBox(height: 12),
        JobOverviewPanel(order: widget.order),
        const SizedBox(height: 14),
        Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Technician Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Record the work completed and anything the office should follow up.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Work completed',
                          hintText:
                              'Describe the repair, installation, or testing completed.',
                          prefixIcon: Icon(Icons.edit_note_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _issueController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Issue or follow-up (optional)',
                          hintText:
                              'Report a safety concern, unresolved fault, or return visit.',
                          prefixIcon: Icon(Icons.report_problem_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Sign-off',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The customer confirms that the work was completed at the site.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _customerController,
                        decoration: const InputDecoration(
                          labelText: 'Customer name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Signature',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _openSignatureCapture,
                            icon: Icon(
                              _strokes.isEmpty
                                  ? Icons.draw_outlined
                                  : Icons.edit_outlined,
                            ),
                            label: Text(
                              _strokes.isEmpty ? 'Capture signature' : 'Edit',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _SignaturePreview(
                        strokes: _strokes,
                        onTap: _openSignatureCapture,
                      ),
                      if (_strokes.isEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Ask the customer to sign inside the box.',
                          style: TextStyle(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save completion details'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSaved(
      widget.order.copyWith(
        technicianNotes: _notesController.text.trim(),
        issueReport: _issueController.text.trim(),
        customerName: _customerController.text.trim(),
        customerSignature: encodeSignature(_strokes),
      ),
    );
  }

  Future<void> _openSignatureCapture() async {
    final strokes = await Navigator.of(context).push<List<List<Offset>>>(
      MaterialPageRoute<List<List<Offset>>>(
        fullscreenDialog: true,
        builder: (context) => FullScreenSignatureScreen(
          initialStrokes: _strokes,
          customerName: _customerController.text.trim(),
        ),
      ),
    );
    if (strokes != null && mounted) setState(() => _strokes = strokes);
  }
}

class _SignaturePreview extends StatelessWidget {
  const _SignaturePreview({required this.strokes, required this.onTap});

  final List<List<Offset>> strokes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border, width: 1.5),
        ),
        child: CustomPaint(
          painter: SignaturePainter(strokes),
          child: strokes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_full, color: AppTheme.muted),
                      SizedBox(height: 7),
                      Text(
                        'Tap to open the full-screen signature pad',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                )
              : const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.open_in_full, color: AppTheme.muted),
                  ),
                ),
        ),
      ),
    );
  }
}

class FullScreenSignatureScreen extends StatefulWidget {
  const FullScreenSignatureScreen({
    super.key,
    required this.initialStrokes,
    required this.customerName,
  });

  final List<List<Offset>> initialStrokes;
  final String customerName;

  @override
  State<FullScreenSignatureScreen> createState() =>
      _FullScreenSignatureScreenState();
}

class _FullScreenSignatureScreenState extends State<FullScreenSignatureScreen> {
  late List<List<Offset>> _strokes = widget.initialStrokes
      .map((stroke) => [...stroke])
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Customer Signature'),
        actions: [
          TextButton.icon(
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(() => _strokes = []),
            icon: const Icon(Icons.refresh),
            label: const Text('Clear'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.customerName.isEmpty
                    ? 'Ask the customer to sign below.'
                    : '${widget.customerName} should sign below.',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Use a finger or stylus. The entire area is available for signing.',
                style: TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _FullScreenSignaturePad(
                  strokes: _strokes,
                  onStrokeStart: _startStroke,
                  onStrokeUpdate: _updateStroke,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _strokes.isEmpty
                      ? null
                      : () => Navigator.pop(context, _strokes),
                  icon: const Icon(Icons.check),
                  label: const Text('Use this signature'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startStroke(Offset point) {
    setState(() {
      _strokes = [
        ..._strokes.map((stroke) => [...stroke]),
        [point],
      ];
    });
  }

  void _updateStroke(Offset point) {
    if (_strokes.isEmpty) return;
    setState(() {
      final updated = _strokes.map((stroke) => [...stroke]).toList();
      updated.last.add(point);
      _strokes = updated;
    });
  }
}

class _FullScreenSignaturePad extends StatelessWidget {
  const _FullScreenSignaturePad({
    required this.strokes,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
  });

  final List<List<Offset>> strokes;
  final ValueChanged<Offset> onStrokeStart;
  final ValueChanged<Offset> onStrokeUpdate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          onStrokeStart(
            _normalize(
              details.localPosition,
              constraints.maxWidth,
              constraints.maxHeight,
            ),
          );
        },
        onPanUpdate: (details) {
          onStrokeUpdate(
            _normalize(
              details.localPosition,
              constraints.maxWidth,
              constraints.maxHeight,
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CustomPaint(
            painter: SignaturePainter(strokes, strokeWidth: 3.2),
            child: strokes.isEmpty
                ? const Center(
                    child: Text(
                      'SIGN HERE',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Offset _normalize(Offset point, double width, double height) {
    return Offset(
      (point.dx / width).clamp(0, 1),
      (point.dy / height).clamp(0, 1),
    );
  }
}

class SignaturePainter extends CustomPainter {
  SignaturePainter(
    this.strokes, {
    this.color = const Color(0xFF17211D),
    this.strokeWidth = 2.4,
  });

  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

String encodeSignature(List<List<Offset>> strokes) {
  return jsonEncode(
    strokes
        .map((stroke) => stroke.map((point) => [point.dx, point.dy]).toList())
        .toList(),
  );
}

List<List<Offset>> decodeSignature(String? value) {
  if (value == null || value.isEmpty) return [];
  try {
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded
        .whereType<List<dynamic>>()
        .map(
          (stroke) => stroke
              .whereType<List<dynamic>>()
              .where((point) => point.length >= 2)
              .map(
                (point) => Offset(
                  (point[0] as num).toDouble(),
                  (point[1] as num).toDouble(),
                ),
              )
              .toList(),
        )
        .where((stroke) => stroke.isNotEmpty)
        .toList();
  } catch (_) {
    return [];
  }
}
