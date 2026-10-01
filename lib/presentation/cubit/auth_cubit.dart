import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_state.dart';

/// Drives sign up / sign in / sign out and keeps [AuthState] in sync with
/// Supabase's own auth state. Subscribing to [AuthRepository.onAuthStateChange]
/// is what gives automatic session restoration for free: `Supabase.initialize()`
/// restores any persisted session before the first event fires, so no custom
/// persistence code is needed here.
///
/// Note the `supabase` import prefix: supabase_flutter exports its own
/// `AuthState` type (an auth-change event), which would otherwise collide
/// with this file's own [AuthState] (the Cubit's presentation state).
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState()) {
    _subscription = _repository.onAuthStateChange.listen(_onAuthStateChange);
  }

  final AuthRepository _repository;
  late final StreamSubscription<supabase.AuthState> _subscription;

  Future<void> _onAuthStateChange(supabase.AuthState data) async {
    final session = data.session;
    if (session == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    // A missing/unreadable `customers` row does NOT mean sign-in failed -
    // that row is created lazily by the backend on the customer's first
    // claim action (see AuthRepository.fetchCustomerProfile), not at
    // sign-in. Treat this as best-effort enrichment of AuthState, never as
    // a reason to withhold AuthStatus.authenticated.
    UserProfile? profile;
    try {
      profile = await _repository.fetchCustomerProfile();
    } catch (e) {
      debugPrint('AuthCubit: could not load customer profile (non-fatal): $e');
    }

    emit(AuthState(status: AuthStatus.authenticated, profile: profile));
  }

  Future<void> signUp({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearErrorMessage: true));
    try {
      await _repository.signUp(email: email, password: password);
      // If this project requires email confirmation, no session exists yet
      // and _onAuthStateChange won't fire with one - surface that instead
      // of leaving the UI stuck on a loading spinner.
      if (_repository.currentUser == null) {
        emit(
          state.copyWith(
            status: AuthStatus.unauthenticated,
            errorMessage: 'Check your email to confirm your account, then sign in.',
          ),
        );
      }
    } on supabase.AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.toString()));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.authenticating, clearErrorMessage: true));
    try {
      await _repository.signIn(email: email, password: password);
      // Success path (emitting `authenticated`) is handled by _onAuthStateChange.
    } on supabase.AuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.toString()));
    }
  }

  Future<void> signOut() => _repository.signOut();

  @override
  Future<void> close() {
    unawaited(_subscription.cancel());
    return super.close();
  }
}
