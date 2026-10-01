import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/claim_device_repository.dart';
import '../../data/repositories/claims_repository.dart';
import '../../data/repositories/receipts_repository.dart';
import '../../domain/entities/claim_failure_reason.dart';
import '../cubit/claim_cubit.dart';
import '../cubit/claim_state.dart';
import '../cubit/receipts_list_cubit.dart';
import '../widgets/qr_widget.dart';
import '../widgets/success_widget.dart';

/// Production entry point: "Ready to tap" arms NFC (HCE) with a
/// backend-issued claim code; the QR scanner underneath is always available
/// as the alternate, independent completion path. Both converge on the
/// same [ClaimCubit].
class ReceiptFlowScreen extends StatelessWidget {
  const ReceiptFlowScreen({
    super.key,
    required this.claimsRepository,
    required this.deviceRepository,
    required this.receiptsRepository,
  });

  final ClaimsRepository claimsRepository;
  final ClaimDeviceRepository deviceRepository;
  final ReceiptsRepository receiptsRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ClaimCubit(
        claimsRepository: claimsRepository,
        deviceRepository: deviceRepository,
        receiptsRepository: receiptsRepository,
        receiptsListCubit: context.read<ReceiptsListCubit>(),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Receipta')),
        body: const Center(child: _ClaimFlowBody()),
      ),
    );
  }
}

class _ClaimFlowBody extends StatelessWidget {
  const _ClaimFlowBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClaimCubit, ClaimState>(
      builder: (context, state) {
        switch (state.status) {
          case ClaimStatus.initial:
          case ClaimStatus.nfcExpired:
          case ClaimStatus.completionTimedOut:
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.status == ClaimStatus.nfcExpired) ...[
                    const Text(
                      'That code expired before it was used.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap Ready to get a new one.'),
                    const SizedBox(height: 16),
                  ],
                  if (state.status == ClaimStatus.completionTimedOut) ...[
                    const Text(
                      "We saw your tap, but couldn't confirm it yet.",
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text('Check My Receipts in a moment, or tap Ready to try again.'),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: () => context.read<ClaimCubit>().armNfc(),
                    child: const Text('Ready to tap'),
                  ),
                  const SizedBox(height: 24),
                  const Text('or scan the QR code on the ESP32 device'),
                  const SizedBox(height: 16),
                  QrWidget(key: ValueKey(state.status)),
                ],
              ),
            );

          case ClaimStatus.arming:
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Requesting a claim code...'),
              ],
            );

          case ClaimStatus.waitingForCustomer:
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tap your phone on the ESP32 device,'),
                  const Text('or scan the QR code it displays.'),
                  const SizedBox(height: 24),
                  QrWidget(key: ValueKey(state.status)),
                ],
              ),
            );

          case ClaimStatus.tapDetected:
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Tap detected - confirming with the register...'),
              ],
            );

          case ClaimStatus.completingViaQr:
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking code...'),
              ],
            );

          case ClaimStatus.success:
            return SuccessWidget(receipt: state.receipt!);

          case ClaimStatus.claimFailed:
            return _ErrorPanel(
              message: _claimFailureMessage(state.failureReason),
              showQrRetry: true,
            );

          case ClaimStatus.networkError:
            return _ErrorPanel(
              message: state.errorMessage ?? 'Could not reach the server. Check your connection.',
              onRetry: () => context.read<ClaimCubit>().armNfc(),
              retryLabel: 'Try again',
            );

          case ClaimStatus.failed:
            return _ErrorPanel(
              message: state.errorMessage ?? 'Something went wrong.',
              onRetry: () => context.read<ClaimCubit>().armNfc(),
              retryLabel: 'Try again',
            );
        }
      },
    );
  }

  String _claimFailureMessage(ClaimFailureReason? reason) {
    switch (reason) {
      case ClaimFailureReason.notFound:
        return "That code wasn't recognized. Make sure you scanned the right QR code.";
      case ClaimFailureReason.expired:
        return 'That QR code has expired.';
      case ClaimFailureReason.alreadyConsumed:
        return 'That receipt has already been claimed.';
      case ClaimFailureReason.wrongType:
        return "That code isn't a QR claim code.";
      case ClaimFailureReason.forbidden:
        return 'This code is not valid for that receipt.';
      case ClaimFailureReason.unknown:
      case null:
        return 'Could not claim that receipt.';
    }
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.showQrRetry = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final bool showQrRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (showQrRetry) QrWidget(key: UniqueKey()),
          if (onRetry != null) ElevatedButton(onPressed: onRetry, child: Text(retryLabel!)),
        ],
      ),
    );
  }
}
