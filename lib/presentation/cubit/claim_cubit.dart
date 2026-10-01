import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exceptions.dart';
import '../../data/repositories/claim_device_repository.dart';
import '../../data/repositories/claims_repository.dart';
import '../../data/repositories/receipts_repository.dart';
import '../../domain/entities/claim_token.dart';
import '../../domain/entities/receipt.dart';
import 'claim_state.dart';
import 'receipts_list_cubit.dart';

/// Drives one claim transaction end-to-end via the real backend:
///
/// NFC: "Ready to tap" -> POST /api/claims -> arm HCE with the returned
/// code -> the app has no synchronous confirmation of the tap (it goes
/// phone -> ESP32 -> Agent -> backend), so completion is detected by
/// polling GET /api/customers/me/receipts, not by the local HCE tap event
/// alone (see NfcService/HceService - that event only means the ESP32 read
/// the tag, not that the backend finished assignment). No table is on the
/// Realtime publication for this project (confirmed against the live
/// project's pg_publication_tables), so polling is what's actually
/// supported today, not a Realtime subscription.
///
/// QR: scanning extracts a bare code string -> POST /api/claims/{code}/scan
/// -> distinguishable failure reasons instead of one generic error.
///
/// Both paths converge on [_complete], guarded against double-completion,
/// and both call [ReceiptsListCubit.refresh] on success.
class ClaimCubit extends Cubit<ClaimState> with WidgetsBindingObserver {
  ClaimCubit({
    required this._claimsRepository,
    required this._deviceRepository,
    required this._receiptsRepository,
    required this._receiptsListCubit,
  }) : super(const ClaimState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _pollInterval = Duration(seconds: 3);
  static const _postTapPollInterval = Duration(seconds: 2);
  static const _postTapTimeout = Duration(seconds: 20);

  final ClaimsRepository _claimsRepository;
  final ClaimDeviceRepository _deviceRepository;
  final ReceiptsRepository _receiptsRepository;
  final ReceiptsListCubit _receiptsListCubit;

  Timer? _expiryTimer;
  Timer? _pollTimer;
  Timer? _postTapTimeoutTimer;
  StreamSubscription<String>? _tapSubscription;
  bool _completing = false;
  bool _polling = false;
  bool _wasArmedBeforeBackground = false;
  DateTime? _armedAt;

  static const _scannableStatuses = {
    ClaimStatus.initial,
    ClaimStatus.waitingForCustomer,
    ClaimStatus.nfcExpired,
    ClaimStatus.completionTimedOut,
  };

  /// "Ready to tap" button.
  Future<void> armNfc() async {
    emit(const ClaimState(status: ClaimStatus.arming));

    final nfcAvailable = await _deviceRepository.isNfcAvailable();
    if (!nfcAvailable) {
      emit(const ClaimState(status: ClaimStatus.failed, errorMessage: 'NFC is not available on this device.'));
      return;
    }

    final ClaimToken token;
    try {
      token = await _claimsRepository.createNfcClaim();
    } on NetworkException catch (e) {
      emit(ClaimState(status: ClaimStatus.networkError, errorMessage: e.message));
      return;
    } on ApiErrorException catch (e) {
      emit(ClaimState(status: ClaimStatus.failed, errorMessage: e.message));
      return;
    }

    try {
      await _deviceRepository.enableHce(token.code);
    } catch (e) {
      emit(ClaimState(status: ClaimStatus.failed, errorMessage: 'Failed to enable NFC: $e'));
      return;
    }

    _completing = false;
    _armedAt = DateTime.now();

    unawaited(_tapSubscription?.cancel());
    _tapSubscription = _deviceRepository.nfcTapEvents.listen(_onNfcTap);

    _scheduleExpiry(token.expiresAt);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollForCompletion());

    emit(ClaimState(status: ClaimStatus.waitingForCustomer, code: token.code, expiresAt: token.expiresAt));
  }

  /// Called by the QR widget with the bare code it decoded.
  Future<void> onQrScanned(String code) async {
    if (_completing || !_scannableStatuses.contains(state.status)) return;
    _completing = true;

    emit(state.copyWith(status: ClaimStatus.completingViaQr));

    try {
      final result = await _claimsRepository.scanQrClaim(code);
      if (result.isSuccess) {
        await _complete(result.receipt!);
      } else {
        _completing = false;
        emit(ClaimState(status: ClaimStatus.claimFailed, failureReason: result.failureReason));
      }
    } on NetworkException catch (e) {
      _completing = false;
      emit(ClaimState(status: ClaimStatus.networkError, errorMessage: e.message));
    }
  }

  void _onNfcTap(String tappedCode) {
    if (_completing || state.status != ClaimStatus.waitingForCustomer) return;

    // The ESP32 read the tag - stop the pre-tap expiry countdown (the code
    // is already consumed on the HCE side) and switch to a faster poll
    // with a bounded timeout while we wait for the Agent -> backend leg.
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_postTapPollInterval, (_) => _pollForCompletion());
    _postTapTimeoutTimer?.cancel();
    _postTapTimeoutTimer = Timer(_postTapTimeout, () {
      if (_completing || state.status != ClaimStatus.tapDetected) return;
      _teardown();
      emit(const ClaimState(status: ClaimStatus.completionTimedOut));
    });

    emit(state.copyWith(status: ClaimStatus.tapDetected));
  }

  Future<void> _pollForCompletion() async {
    // Timer.periodic fires on schedule regardless of whether the previous
    // tick's request finished - without this guard, two overlapping polls
    // could both find the same match and both call _complete.
    if (_polling || _completing) return;
    if (state.status != ClaimStatus.waitingForCustomer && state.status != ClaimStatus.tapDetected) return;

    final armedAt = _armedAt;
    if (armedAt == null) return;

    _polling = true;
    try {
      final page = await _receiptsRepository.getMyReceipts(page: 1, pageSize: 5);
      Receipt? match;
      for (final receipt in page.items) {
        if (receipt.assignmentMethod == ClaimAssignmentMethod.nfc &&
            receipt.assignedAt != null &&
            receipt.assignedAt!.isAfter(armedAt)) {
          match = receipt;
          break;
        }
      }
      if (match != null) {
        await _complete(match);
      }
    } on NetworkException {
      // Transient - the next tick retries. Don't flip the whole screen to
      // an error state over one missed poll.
    } on ApiErrorException {
      // Same reasoning - a single bad poll response shouldn't interrupt an
      // otherwise-successful wait.
    } finally {
      _polling = false;
    }
  }

  /// By the time this is called, the caller has already established (via
  /// `_completing`/`_polling`) that this is the only in-flight completion.
  Future<void> _complete(Receipt receipt) async {
    _completing = true;
    _teardown();

    emit(ClaimState(status: ClaimStatus.success, receipt: receipt));
    unawaited(_receiptsListCubit.refresh());

    await Future<void>.delayed(const Duration(seconds: 3));
    if (isClosed) return;
    unawaited(armNfc());
  }

  void _scheduleExpiry(DateTime expiresAt) {
    _expiryTimer?.cancel();
    final remaining = expiresAt.difference(DateTime.now());
    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (_completing || state.status != ClaimStatus.waitingForCustomer) return;
      _teardown();
      emit(const ClaimState(status: ClaimStatus.nfcExpired));
    });
  }

  /// Cancels all timers/subscriptions and disarms HCE. Does not emit -
  /// callers emit the state that follows.
  void _teardown() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _postTapTimeoutTimer?.cancel();
    _postTapTimeoutTimer = null;
    unawaited(_tapSubscription?.cancel());
    _tapSubscription = null;
    unawaited(_deviceRepository.disableHce());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        if (_wasArmedBeforeBackground) {
          _wasArmedBeforeBackground = false;
          unawaited(armNfc());
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (state.status == ClaimStatus.waitingForCustomer || state.status == ClaimStatus.tapDetected) {
          _wasArmedBeforeBackground = true;
          _completing = false;
          _teardown();
          emit(const ClaimState(status: ClaimStatus.initial));
        }
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _teardown();
    return super.close();
  }
}
