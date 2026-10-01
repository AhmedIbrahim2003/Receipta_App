import 'package:equatable/equatable.dart';

import '../../domain/entities/receipt.dart';

enum ReceiptsListStatus { initial, loading, loaded, networkError, failed }

class ReceiptsListState extends Equatable {
  const ReceiptsListState({
    this.status = ReceiptsListStatus.initial,
    this.receipts = const [],
    this.errorMessage,
  });

  final ReceiptsListStatus status;
  final List<Receipt> receipts;
  final String? errorMessage;

  ReceiptsListState copyWith({
    ReceiptsListStatus? status,
    List<Receipt>? receipts,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ReceiptsListState(
      status: status ?? this.status,
      receipts: receipts ?? this.receipts,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, receipts, errorMessage];
}
