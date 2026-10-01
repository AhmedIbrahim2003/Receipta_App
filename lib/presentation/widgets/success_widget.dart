import 'package:flutter/material.dart';

import '../../domain/entities/receipt.dart';

class SuccessWidget extends StatelessWidget {
  const SuccessWidget({super.key, required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 16),
        const Text(
          'Receipt received successfully',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${receipt.currency} ${receipt.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16),
        ),
        if (receipt.receiptNumber != null)
          Text('Receipt #${receipt.receiptNumber}', style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
