import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

/// Reports whether this device has usable NFC hardware.
///
/// Used to fail fast with [ReceiptStatus.failed] instead of arming HCE and
/// waiting forever on a device that has no NFC radio at all.
class NfcService {
  const NfcService();

  Future<bool> isAvailable() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      return availability == NFCAvailability.available;
    } on PlatformException {
      return false;
    }
  }
}
