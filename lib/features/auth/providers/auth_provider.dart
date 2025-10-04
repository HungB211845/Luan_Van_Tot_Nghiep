import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_state.dart' as auth;
import '../models/store.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/biometric_service.dart';
import '../services/store_service.dart';
import '../../../shared/services/base_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();
  StreamSubscription<AuthState>? _authSub;
  Timer? _biometricSessionTimer;

  auth.AuthState _state = const auth.AuthState(status: auth.AuthStatus.initial, isLoading: false);
  bool _isRecentBiometricLogin = false;

  auth.AuthState get state => _state;
  bool get isAuthenticated => _state.isAuthenticated;
  UserProfile? get currentUser => _state.userProfile;
  Store? get currentStore => _state.store;

  Future<void> initialize() async {
    _setState(_state.copyWith(isLoading: true));
    try {
      // Listen for auth state changes (OAuth callbacks, sign-in/sign-out from deep links)
      _authSub ??= Supabase.instance.client.auth.onAuthStateChange.listen(_handleAuthChange);

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // CRITICAL: Validate refresh token format before trusting the session
        final isValidToken = await _authService.isValidRefreshToken(session.refreshToken);

        if (!isValidToken) {
          print('🚨 DEBUG: Detected corrupted refresh token, clearing storage...');
          await _authService.clearCorruptedStorage();
          _setState(const auth.AuthState(status: auth.AuthStatus.unauthenticated, isLoading: false));
          return;
        }

        final valid = await _sessionService.validateSession();
        if (valid) {
          // load profile & store
          final profile = await _authService.getUserProfile(session.user.id);
          Store? store;
          if (profile != null) {
            store = await StoreService().getStoreById(profile.storeId);
          }
          // Cache for store-aware BaseService
          if (profile != null) {
            BaseService.setCurrentUserProfile(profile);
            BaseService.setCurrentUserStoreId(profile.storeId);
          } else {
            BaseService.setCurrentUserProfile(null);
            BaseService.setCurrentUserStoreId(null);
          }
          _setState(auth.AuthState(status: auth.AuthStatus.authenticated, userProfile: profile, store: store, isLoading: false));
          return;
        }
      }

      // fallback: biometric available and enabled on this device
      final canBio = await BiometricService.isAvailable();
      final hasBiometricToken = await _authService.isBiometricAvailableAndEnabled();
      if (canBio && hasBiometricToken) {
        print('🔍 DEBUG: Biometric available and has stored token - showing biometric option');
        _setState(_state.copyWith(status: auth.AuthStatus.biometricAvailable, isLoading: false));
      } else {
        if (canBio) {
          print('🔍 DEBUG: Device supports biometric but no stored token');
        } else {
          print('🔍 DEBUG: Device does not support biometric');
        }
        _setState(_state.copyWith(status: auth.AuthStatus.unauthenticated, isLoading: false));
      }
    } catch (e) {
      _setState(_state.copyWith(status: auth.AuthStatus.unauthenticated, errorMessage: e.toString(), isLoading: false));
    }
  }

  Future<void> _handleAuthChange(AuthState data) async {
    final event = data.event;
    final session = data.session;
    
    // 🚀🚀🚀 ADDING EXTENSIVE LOGGING 🚀🚀🚀
    print('Auth Event Fired: ${event.name}');
    if (session != null) {
      print('  - Session User: ${session.user.id}');
      final token = session.refreshToken;
      print('  - Refresh Token Exists: ${token != null}');
      if (token != null) {
        print('  - Refresh Token Length: ${token.length}');
        print('  - Refresh Token is JWT: ${token.length > 50 && token.split('.').length == 3}');
      }
    } else {
      print('  - Session is NULL');
    }
    // 🚀🚀🚀 END OF LOGGING 🚀🚀🚀

    switch (data.event) {
      case AuthChangeEvent.signedIn:
        // Don't save token here, wait for userUpdated event after metadata is set
        final session = data.session;
        if (session?.user != null) {
          try {
            final profile = await _authService.getUserProfile(session!.user.id);
            Store? store;
            if (profile != null) {
              store = await StoreService().getStoreById(profile.storeId);
            }
            if (profile != null) {
              BaseService.setCurrentUserProfile(profile);
              BaseService.setCurrentUserStoreId(profile.storeId);
            } else {
              BaseService.setCurrentUserProfile(null);
              BaseService.setCurrentUserStoreId(null);
            }
            _setState(auth.AuthState(status: auth.AuthStatus.authenticated, userProfile: profile, store: store, isLoading: false));
          } catch (e) {
            _setState(_state.copyWith(errorMessage: e.toString(), isLoading: false));
          }
        }
        break;
      
      case AuthChangeEvent.userUpdated:
        // This event fires after updateUserMetadata. This is the reliable time to save the token.
        print('AuthProvider: UserUpdated event detected. Checking for valid refresh token...');
        final session = data.session;
        if (session?.refreshToken != null) {
          final token = session!.refreshToken!;
          if (token.length > 50 && token.split('.').length == 3) {
            print('AuthProvider: Detected valid refresh token on UserUpdated event. Saving for biometric...');
            await _authService.saveRefreshTokenForBiometric(token);
          } else {
            print('AuthProvider: Invalid or short refresh token on UserUpdated event. Checking if recent biometric login...');
            if (_isRecentBiometricLogin) {
              print('AuthProvider: Skipping biometric cleanup - recent biometric login detected');
            } else {
              print('AuthProvider: Proceeding with biometric cleanup - no recent biometric login');
              await _authService.disableBiometric(); // This will clear the stored token
            }
          }
        }
        // Also refresh the user profile in the state, as it might have changed
        if (session?.user != null) {
          final profile = await _authService.getUserProfile(session!.user.id);
          _setState(_state.copyWith(userProfile: profile));
        }
        break;

      case AuthChangeEvent.tokenRefreshed:
        // This is also a good place to re-save the token
        final session = data.session;
        if (session?.refreshToken != null) {
          final token = session!.refreshToken!;
          if (token.length > 50 && token.split('.').length == 3) {
            print('AuthProvider: Detected valid refresh token on TokenRefreshed event. Saving for biometric...');
            await _authService.saveRefreshTokenForBiometric(token);
          }
        }
        if (session?.user != null) {
           final profile = await _authService.getUserProfile(session!.user.id);
           _setState(_state.copyWith(userProfile: profile));
        }
        break;

      case AuthChangeEvent.signedOut:
        _setState(const auth.AuthState(status: auth.AuthStatus.unauthenticated, isLoading: false));
        break;
      default:
        break;
    }
  }

  /// Legacy login method - DEPRECATED for security
  @Deprecated('Use signInWithStore() instead for multi-tenant security')
  Future<bool> signIn(String email, String password) async {
    // Force users to use store-aware login
    throw UnsupportedError(
      'Direct email/password login is not allowed. '
      'Use signInWithStore(email, password, storeCode) instead for security.'
    );
  }

  /// NEW: Store-aware login method
  Future<bool> signInWithStore({
    required String email, 
    required String password, 
    required String storeCode
  }) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    final result = await _authService.signInWithEmailAndStore(
      email: email, 
      password: password, 
      storeCode: storeCode
    );
    if (result.isSuccess && result.profile != null) {
      BaseService.setCurrentUserProfile(result.profile);
      BaseService.setCurrentUserStoreId(result.profile!.storeId);
      _setState(auth.AuthState(status: auth.AuthStatus.authenticated, userProfile: result.profile, store: result.store, isLoading: false));
      return true;
    }
    _setState(_state.copyWith(errorMessage: result.errorMessage, isLoading: false));
    return false;
  }

  /// NEW: Store-aware biometric authentication
  Future<bool> signInWithBiometric() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));

    // Set protection flag BEFORE login to prevent race condition with auth events
    _isRecentBiometricLogin = true;
    _biometricSessionTimer?.cancel();
    _biometricSessionTimer = Timer(const Duration(seconds: 15), () {
      _isRecentBiometricLogin = false;
      print('🔍 DEBUG: Biometric session flag reset');
    });
    print('🔍 DEBUG: Set biometric protection flag BEFORE login attempt (15 seconds)');

    final result = await _authService.signInWithBiometric();
    if (result.isSuccess && result.profile != null) {
      BaseService.setCurrentUserProfile(result.profile);
      BaseService.setCurrentUserStoreId(result.profile!.storeId);

      print('🔍 DEBUG: Biometric login successful - protection flag remains active');
      _setState(auth.AuthState(status: auth.AuthStatus.authenticated, userProfile: result.profile, store: result.store, isLoading: false));
      return true;
    } else {
      // Failed - clear protection flag immediately
      _isRecentBiometricLogin = false;
      _biometricSessionTimer?.cancel();
      print('🔍 DEBUG: Biometric login failed - cleared protection flag immediately');
    }
    _setState(_state.copyWith(errorMessage: result.errorMessage, isLoading: false));
    return false;
  }

  /// Enable biometric authentication with password verification
  Future<bool> enableBiometricWithPassword({
    required String email,
    required String password,
    required String storeCode,
  }) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    final result = await _authService.enableBiometricWithPassword(
      email: email,
      password: password,
      storeCode: storeCode,
    );
    if (result.isSuccess) {
      // Refresh user profile to get updated biometric_enabled status
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final profile = await _authService.getUserProfile(session.user.id);
        if (profile != null) {
          _setState(_state.copyWith(userProfile: profile, isLoading: false));
        }
      }
      _setState(_state.copyWith(isLoading: false));
      return true;
    }
    _setState(_state.copyWith(errorMessage: result.errorMessage, isLoading: false));
    return false;
  }

  /// Enable biometric authentication for current user (legacy method)
  @Deprecated('Use enableBiometricWithPassword() instead')
  Future<bool> enableBiometric() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    final result = await _authService.enableBiometric();
    if (result.isSuccess) {
      // Refresh user profile to get updated biometric_enabled status
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final profile = await _authService.getUserProfile(session.user.id);
        if (profile != null) {
          _setState(_state.copyWith(userProfile: profile, isLoading: false));
        }
      }
      _setState(_state.copyWith(isLoading: false));
      return true;
    }
    _setState(_state.copyWith(errorMessage: result.errorMessage, isLoading: false));
    return false;
  }

  /// Disable biometric authentication for current user
  Future<bool> disableBiometric() async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    final result = await _authService.disableBiometric();
    if (result.isSuccess) {
      // Refresh user profile to get updated biometric_enabled status
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final profile = await _authService.getUserProfile(session.user.id);
        if (profile != null) {
          _setState(_state.copyWith(userProfile: profile, isLoading: false));
        }
      }
      _setState(_state.copyWith(isLoading: false));
      return true;
    }
    _setState(_state.copyWith(errorMessage: result.errorMessage, isLoading: false));
    return false;
  }

  /// Check if biometric authentication is available and enabled
  Future<bool> isBiometricAvailableAndEnabled() async {
    return await _authService.isBiometricAvailableAndEnabled();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    // The auth state will be updated by the _handleAuthChange listener.
  }

  Future<void> switchStore() async {
    await _authService.clearLastStoreCode();
    await signOut();
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String storeCode,
    required String fullName,
    required String storeName,
    String? phone,
  }) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    final result = await _authService.signUpWithEmail(
      email: email,
      password: password,
      storeCode: storeCode,
      fullName: fullName,
      storeName: storeName,
      phone: phone,
    );
    if (result.isSuccess) {
      if (result.profile != null) {
        BaseService.setCurrentUserProfile(result.profile);
        BaseService.setCurrentUserStoreId(result.profile!.storeId);
      } else {
        BaseService.setCurrentUserProfile(null);
        BaseService.setCurrentUserStoreId(null);
      }
      _setState(auth.AuthState(status: auth.AuthStatus.authenticated, userProfile: result.profile, store: result.store, isLoading: false));
      return true;
    }
    _setState(_state.copyWith(errorMessage: result.errorMessage, isLoading: false));
    return false;
  }

  /// Validates the store code and saves it for the session.
  Future<Store?> validateAndSetStore(String storeCode) async {
    _setState(_state.copyWith(isLoading: true, errorMessage: null));
    try {
      final store = await _authService.validateAndSetStore(storeCode);
      if (store != null) {
        _setState(_state.copyWith(store: store, isLoading: false));
        return store;
      }
      return null;
    } catch (e) {
      _setState(_state.copyWith(errorMessage: e.toString().replaceAll('Exception: ', ''), isLoading: false));
      return null;
    }
  }

  /// Checks store code availability.
  Future<Map<String, dynamic>> checkStoreCodeAvailability(String storeCode) async {
    return await _authService.checkStoreCodeAvailability(storeCode);
  }

  void _setState(auth.AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _biometricSessionTimer?.cancel();
    super.dispose();
  }
}
