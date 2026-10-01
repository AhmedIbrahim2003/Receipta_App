import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/receipts_repository.dart';
import '../../domain/entities/receipt.dart';
import '../cubit/receipts_list_cubit.dart';
import '../cubit/receipts_list_state.dart';
import 'receipt_detail_screen.dart';

/// GET /api/customers/me/receipts. Uses the [ReceiptsListCubit] already
/// provided at the app root, so it reflects claims completed elsewhere in
/// the app (see ClaimCubit's `refresh()` call on success) without needing
/// its own fetch-on-every-navigation logic beyond an initial load.
class ReceiptsListScreen extends StatefulWidget {
  const ReceiptsListScreen({super.key, required this.receiptsRepository});

  final ReceiptsRepository receiptsRepository;

  @override
  State<ReceiptsListScreen> createState() => _ReceiptsListScreenState();
}

class _ReceiptsListScreenState extends State<ReceiptsListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ReceiptsListCubit>().fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Receipts')),
      body: BlocBuilder<ReceiptsListCubit, ReceiptsListState>(
        builder: (context, state) {
          switch (state.status) {
            case ReceiptsListStatus.initial:
            case ReceiptsListStatus.loading:
              return const Center(child: CircularProgressIndicator());

            case ReceiptsListStatus.networkError:
            case ReceiptsListStatus.failed:
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage ?? 'Could not load your receipts.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<ReceiptsListCubit>().fetch(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );

            case ReceiptsListStatus.loaded:
              if (state.receipts.isEmpty) {
                return const Center(child: Text('No receipts yet.'));
              }
              return RefreshIndicator(
                onRefresh: () => context.read<ReceiptsListCubit>().fetch(),
                child: ListView.separated(
                  itemCount: state.receipts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final receipt = state.receipts[index];
                    return _ReceiptListTile(
                      receipt: receipt,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceiptDetailScreen(
                            receipt: receipt,
                            receiptsRepository: widget.receiptsRepository,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

class _ReceiptListTile extends StatelessWidget {
  const _ReceiptListTile({required this.receipt, required this.onTap});

  final Receipt receipt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(receipt.receiptNumber ?? receipt.id),
      subtitle: Text(_subtitle(receipt)),
      trailing: Text('${receipt.currency} ${receipt.totalAmount.toStringAsFixed(2)}'),
    );
  }

  String _subtitle(Receipt receipt) {
    final method = switch (receipt.assignmentMethod) {
      ClaimAssignmentMethod.qr => 'QR',
      ClaimAssignmentMethod.nfc => 'NFC',
      _ => null,
    };
    final status = receipt.status.displayName;
    return method == null ? status : '$status - via $method';
  }
}
