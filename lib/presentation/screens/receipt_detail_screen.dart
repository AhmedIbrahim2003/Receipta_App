import 'package:flutter/material.dart';

import '../../core/network/api_exceptions.dart';
import '../../data/repositories/receipts_repository.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/entities/receipt_file.dart';

/// Shows a receipt already fetched by the list screen (GET
/// /api/customers/me/receipts returns full ReceiptDto per item, items
/// included) - no separate detail fetch needed. Only "view file" makes its
/// own call, to GET /api/receipts/{id}/file.
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({super.key, required this.receipt, required this.receiptsRepository});

  final Receipt receipt;
  final ReceiptsRepository receiptsRepository;

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

enum _FileLoadStatus { idle, loading, loaded, error }

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  _FileLoadStatus _fileStatus = _FileLoadStatus.idle;
  ReceiptFile? _file;
  String? _fileError;

  Future<void> _loadFile() async {
    setState(() => _fileStatus = _FileLoadStatus.loading);
    try {
      final file = await widget.receiptsRepository.getReceiptFileUrl(widget.receipt.id);
      if (!mounted) return;
      setState(() {
        _file = file;
        _fileStatus = _FileLoadStatus.loaded;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fileError = e.message;
        _fileStatus = _FileLoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    return Scaffold(
      appBar: AppBar(title: Text(receipt.receiptNumber ?? 'Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${receipt.currency} ${receipt.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Status: ${receipt.status.displayName}'),
          if (receipt.assignmentMethod != null)
            Text('Claimed via: ${receipt.assignmentMethod!.name}'),
          if (receipt.assignedAt != null) Text('Assigned: ${receipt.assignedAt}'),
          const SizedBox(height: 24),
          if (receipt.items.isNotEmpty) ...[
            const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final item in receipt.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text('${item.quantity} x ${item.unitPrice.toStringAsFixed(2)}'),
                trailing: Text(item.totalPrice.toStringAsFixed(2)),
              ),
            const Divider(height: 32),
          ],
          _buildFileSection(),
        ],
      ),
    );
  }

  Widget _buildFileSection() {
    switch (_fileStatus) {
      case _FileLoadStatus.idle:
        return ElevatedButton(onPressed: _loadFile, child: const Text('View file'));
      case _FileLoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _FileLoadStatus.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fileError ?? 'Could not load the file.', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadFile, child: const Text('Retry')),
          ],
        );
      case _FileLoadStatus.loaded:
        final file = _file!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              // The backend returns this same shape while R2 is disabled,
              // just with a placeholder URL instead of a real signed one.
              "File URL (may be a placeholder while file storage isn't fully enabled):",
            ),
            const SizedBox(height: 8),
            SelectableText(file.url),
            const SizedBox(height: 4),
            Text(
              'Link expires: ${file.expiresAt}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        );
    }
  }
}
