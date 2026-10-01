import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../domain/entities/user_profile.dart';
import '../models/user_profile_model.dart';

/// Single point of contact between the presentation layer (Cubit) and the
/// Supabase-backed auth/profile data sources.
class AuthRepository {
  AuthRepository({required this._authService, SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final AuthService _authService;
  final SupabaseClient _client;

  User? get currentUser => _authService.currentUser;

  Stream<AuthState> get onAuthStateChange => _authService.onAuthStateChange;

  Future<void> signUp({required String email, required String password}) async {
    await _authService.signUp(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _authService.signIn(email: email, password: password);
  }

  Future<void> signOut() => _authService.signOut();

  /// Best-effort read of the caller's `public.customers` row. Returns null
  /// if it doesn't exist yet - the backend creates it lazily
  /// (CustomerRepository.EnsureExistsAsync) on the customer's first claim
  /// action, not at sign-up/in. This deliberately does not insert/upsert:
  /// the RLS policies on `customers` grant this app SELECT only (see
  /// reference-schema.sql - "all mutations go through the .NET backend
  /// using its BYPASSRLS role"), so an insert from here would just be
  /// rejected.
  Future<UserProfile?> fetchCustomerProfile() async {
    final user = _authService.currentUser;
    if (user == null) {
      throw StateError('fetchCustomerProfile() called with no signed-in user.');
    }

    final row = await _client.from('customers').select().eq('id', user.id).maybeSingle();
    if (row == null) return null;
    return UserProfileModel.fromJson(row).toEntity();
  }
}
