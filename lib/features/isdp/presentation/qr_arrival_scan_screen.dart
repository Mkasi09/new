import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/entities.dart';

class QrArrivalScanScreen extends StatefulWidget {
  const QrArrivalScanScreen({
    super.key,
    required this.order,
    this.onMatched,
    this.onCancel,
  });

  final WorkOrder order;
  final ValueChanged<bool>? onMatched;
  final VoidCallback? onCancel;

  @override
  State<QrArrivalScanScreen> createState() => _QrArrivalScanScreenState();
}

class _QrArrivalScanScreenState extends State<QrArrivalScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;
  bool _matched = false;
  String? _lastError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;

      if (value == widget.order.siteCode) {
        _showMatched();
      } else {
        _showMismatch(value);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: widget.onCancel ?? () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Site QR',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Switch camera',
                    onPressed: _controller.switchCamera,
                    icon: const Icon(Icons.cameraswitch_outlined),
                  ),
                  IconButton(
                    tooltip: 'Flash',
                    onPressed: _controller.toggleTorch,
                    icon: const Icon(Icons.flash_on_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              const _ScannerFrame(),
              Positioned(
                left: 16,
                right: 16,
                bottom: 28,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.order.site,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.order.address,
                          style: const TextStyle(color: AppTheme.muted),
                          textAlign: TextAlign.center,
                        ),
                        if (_matched) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Arrival confirmed. Proceed with the job.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        if (_lastError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _lastError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (_matched)
                          FilledButton.icon(
                            onPressed: () => _finish(true),
                            icon: const Icon(Icons.today_outlined),
                            label: const Text('Proceed'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _showMatched,
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Demo Verify'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _finish(bool matched) {
    final onMatched = widget.onMatched;
    if (onMatched != null) {
      onMatched(matched);
    } else {
      Navigator.pop(context, matched);
    }
  }

  void _showMatched() {
    if (_handled) return;
    setState(() {
      _handled = true;
      _matched = true;
      _lastError = null;
    });
    _controller.stop();
  }

  void _showMismatch(String scannedValue) {
    setState(() {
      _lastError = 'Wrong QR scanned: $scannedValue';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR does not match this job.')),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 245,
        height: 245,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 4),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}
