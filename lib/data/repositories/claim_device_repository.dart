import '../../core/services/hce_service.dart';
import '../../core/services/nfc_service.dart';

/// Controls the on-device NFC/HCE hardware for the claim flow. Does not
/// generate or know about claim codes itself - callers arm it with a code
/// obtained from [ClaimsRepository.createNfcClaim] (backend-issued, never
/// generated on-device).
class ClaimDeviceRepository {
  ClaimDeviceRepository({required this._hceService, required this._nfcService});

  final HceService _hceService;
  final NfcService _nfcService;

  Future<bool> isNfcAvailable() => _nfcService.isAvailable();

  Future<void> enableHce(String code) => _hceService.startHce(code);

  Future<void> disableHce() => _hceService.stopHce();

  /// Fires with the claim code each time the ESP32 reads it over NFC. This
  /// is a *local* tap event only - it does not mean the backend has
  /// finished assignment (tap -> ESP32 -> Agent -> backend still has to
  /// happen), so callers must still confirm completion via polling.
  Stream<String> get nfcTapEvents => _hceService.onTapSuccess;
}
