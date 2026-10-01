import 'package:flutter/services.dart';

/// Wraps the native Android HCE (Host Card Emulation) channel.
///
/// Two channels are used:
/// - a [MethodChannel] to *command* the native side (`startHce`/`stopHce`),
/// - an [EventChannel] to *receive* the native side telling Dart that the
///   ESP32 actually tapped and consumed the active claim code. That event
///   only happens inside `ReceiptHostApduService` on the Android side, so
///   there is no other way for the Cubit to learn about it.
///
/// The value broadcast is always the backend-issued claim `code` from
/// `POST /api/claims` - never generated on-device.
class HceService {
  HceService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel('receipta/hce'),
       _eventChannel = eventChannel ?? const EventChannel('receipta/hce/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Future<void> startHce(String code) async {
    await _methodChannel.invokeMethod<void>('startHce', {'code': code});
  }

  Future<void> stopHce() async {
    await _methodChannel.invokeMethod<void>('stopHce');
  }

  /// Emits the claim `code` each time the ESP32 successfully reads it over NFC.
  Stream<String> get onTapSuccess {
    return _eventChannel.receiveBroadcastStream().where((event) {
      return event is Map && event['event'] == 'tapSuccess';
    }).map((event) => (event as Map)['code'] as String);
  }
}
