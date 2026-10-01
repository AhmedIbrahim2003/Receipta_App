import 'package:equatable/equatable.dart';

import '../../domain/entities/user_profile.dart';

enum AuthStatus {
  /// Still resolving whether a persisted session exists.
  unknown,
  authenticating,
  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.profile,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserProfile? profile;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    bool clearProfile = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, profile, errorMessage];
}
