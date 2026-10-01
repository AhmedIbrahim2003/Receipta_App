import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../cubit/claim_cubit.dart';

/// Lean scanner for the ESP32's receipt QR code.
///
/// Unlike [MobileScannerAdvanced] (kept as a separate demo screen), this
/// widget has no configuration UI - it just scans and reports the first
/// decoded value (a bare claim `code`, not a full receipt) to the
/// [ClaimCubit]. Give this widget a new `key` (e.g. keyed off the claim
/// status) whenever scanning should be re-enabled after a failed scan -
/// `_reported` is intentionally permanent for the lifetime of one widget
/// instance, so a fresh instance is what resets it.
class QrWidget extends StatefulWidget {
  const QrWidget({super.key});

  @override
  State<QrWidget> createState() => _QrWidgetState();
}

class _QrWidgetState extends State<QrWidget> {
  final MobileScannerController _controller = MobileScannerController();
  bool _reported = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_reported) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _reported = true;
    context.read<ClaimCubit>().onQrScanned(value);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 260,
        height: 260,
        child: MobileScanner(controller: _controller, onDetect: _onDetect),
      ),
    );
  }
}

extension on List<Barcode> {
  Barcode? get firstOrNull => isEmpty ? null : first;
}
