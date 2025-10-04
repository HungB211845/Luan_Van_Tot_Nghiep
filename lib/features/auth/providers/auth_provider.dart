import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_state.dart' as auth;
import '../models/store.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
// import '../services/biometric_service.dart'; // COMMENTED OUT: Biometric functionality removed
import '../services/store_service.dart';
import '../../../shared/services/base_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SessionService _sessionService = SessionService();
  StreamSubscription<AuthState>? _authSub;

  auth.AuthState _state = const auth.AuthState(status: auth.AuthStatus.initial, isLoading: false);

  auth.AuthState get state => _state;
  bool get isAuthenticated => _state.isAuthenticated;
  UserProfile? get currentUser => _state.userProfile;
  Store? get currentStore => _state.store;

  Future<void> initialize() async {
    _setState(_state.copyWith(isLoading: true));
    try {
      _authSub ??= Supabase.instance.client.auth.onAuthStateChange.listen(_handleAuthChange);

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final valid = await _sessionService.validateSession();
        if (valid) {
          final profile = await _authService.getUserProfile(session.user.id);
          Store? store;
          if (profile != null) {
            store = await StoreService().getStoreById(profile.storeId);
          }
          if (profile != null) {
            BaseService.setCurrentUserProfile(profile);
            BaseService.setCurrentUserStoreId(profile.storeId);
          }
          _setState(auth.AuthState(status: auth.AuthStatus.authenticated, userProfile: profile, store: store, isLoading: false));
          return;
        }
      }
      _setState(_state.copyWith(status: auth.AuthStatus.unauthenticated, isLoading: false));
    } catch (e) {
      _setState(_state.copyWith(status: auth.AuthStatus.unauthenticated, errorMessage: e.toString(), isLoading: false));
    }
  }

  Future<void> _handleAuthChange(AuthState data) async {
    switch (data.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
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
            }
            _setState(auth.AuthState(status: auth.AuthStatus.authenticated, userProfile: profile, store: store, isLoading: false));
          } catch (e) {
            _setState(_state.copyWith(errorMessage: e.toString(), isLoading: false));
          }
        }
        break;
      case AuthChangeEvent.signedOut:
        _setState(const auth.AuthState(status: auth.AuthStatus.unauthenticated, isLoading: false));
        break;
      default:
        break;
    }
  }

  @Deprecated('Use signInWithStore() instead for multi-tenant security')
  Future<bool> signIn(String email, String password) async {
    throw UnsupportedError(
      'Direct email/password login is not allowed. '
      'Use signInWithStore(email, password, storeCode) instead for security.'
    );
  }

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

  Future<void> signOut() async {
    await _authService.signOut();
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
      }
      _setState(auth.AuthState(status: auth.AuthStatus.authenticated, userProfile: result.profile, store: result.store, isLoading: false));
      return true;
    }
    _setState(_state.copyWith(errorMessage: result.errorMessage, isLoading: false));
    return false;
  }

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
    super.dispose();
  }
}
