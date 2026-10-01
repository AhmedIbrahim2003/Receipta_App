import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exceptions.dart';
import '../../data/repositories/receipts_repository.dart';
import 'receipts_list_state.dart';

/// Owns "My Receipts" (GET /api/customers/me/receipts). Provided at the app
/// root (alongside AuthCubit) so both the receipts list screen and the
/// claim flow can reach it - the claim flow calls [refresh] after a
/// successful claim so the list reflects the newly assigned receipt.
///
/// Fetches a single page (50 items) rather than implementing infinite
/// scroll - not needed at this app's scale, and paging further is a small
/// addition later if it becomes necessary.
class ReceiptsListCubit extends Cubit<ReceiptsListState> {
  ReceiptsListCubit(this._repository) : super(const ReceiptsListState());

  final ReceiptsRepository _repository;

  Future<void> fetch() async {
    emit(state.copyWith(status: ReceiptsListStatus.loading, clearErrorMessage: true));
    await _load();
  }

  /// Same as [fetch] but intended for silent re-fetches (e.g. after a claim
  /// completes) - still shows the loading state if the list is empty so far,
  /// but doesn't clear an already-loaded list while refreshing.
  Future<void> refresh() async {
    if (state.receipts.isEmpty) {
      emit(state.copyWith(status: ReceiptsListStatus.loading, clearErrorMessage: true));
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      final page = await _repository.getMyReceipts(page: 1, pageSize: 50);
      emit(ReceiptsListState(status: ReceiptsListStatus.loaded, receipts: page.items));
    } on NetworkException catch (e) {
      emit(
        state.copyWith(status: ReceiptsListStatus.networkError, errorMessage: e.message),
      );
    } on ApiErrorException catch (e) {
      emit(state.copyWith(status: ReceiptsListStatus.failed, errorMessage: e.message));
    }
  }
}
