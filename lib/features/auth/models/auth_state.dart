import 'store.dart';
import 'user_profile.dart';
import 'user_session.dart';

enum AuthStatus {
  initial,
  unauthenticated,
  authenticated,
  needsSetup,
  needsVerification,
  biometricAvailable,
  sessionExpired,
}

class AuthState {
  final AuthStatus status;
  final UserProfile? userProfile;
  final Store? store;
  final UserSession? currentSession;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    required this.status,
    this.userProfile,
    this.store,
    this.currentSession,
    this.errorMessage,
    this.isLoading = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get canUseBiometric => status == AuthStatus.biometricAvailable;
  bool get needsStoreSetup => status == AuthStatus.needsSetup;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? userProfile,
    Store? store,
    UserSession? currentSession,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      userProfile: userProfile ?? this.userProfile,
      store: store ?? this.store,
      currentSession: currentSession ?? this.currentSession,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
