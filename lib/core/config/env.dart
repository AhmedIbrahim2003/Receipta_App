/// Compile-time configuration, supplied via `--dart-define` or
/// `--dart-define-from-file=env.json` (see env.json.example). No secrets are
/// ever written into source.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Base URL of the ReceiptSystem.API backend, e.g. `http://192.168.1.20:5169`.
  /// NOT `localhost` for device testing - NFC/HCE requires a physical device,
  /// which can't reach the dev machine's own localhost. Use the dev
  /// machine's LAN IP instead (backend's dev profile listens on
  /// http://localhost:5169 - see ReceiptSystem.API/Properties/launchSettings.json).
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
}
