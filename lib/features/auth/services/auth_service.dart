import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/models/store.dart';
import '../../auth/models/user_profile.dart';
import 'secure_storage_service.dart';
import 'biometric_service.dart';
import 'store_service.dart';
import 'session_service.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final User? user;
  final UserProfile? profile;
  final Store? store;

  AuthResult.success({this.user, this.profile, this.store})
      : isSuccess = true,
        errorMessage = null;

  AuthResult.failure(this.errorMessage)
      : isSuccess = false,
        user = null,
        profile = null,
        store = null;
}

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SecureStorageService _secure = SecureStorageService();

  /// Legacy login method - DEPRECATED for security  
  @Deprecated('Use signInWithEmailAndStore() instead for multi-tenant security')
  Future<AuthResult> signInWithEmail(String email, String password) async {
    // Force users to use store-aware login
    throw UnsupportedError(
      'Direct email/password login is not allowed. '
      'Use signInWithEmailAndStore(email, password, storeCode) instead for security.'
    );
  }

  /// NEW: Store-aware authentication method
  Future<AuthResult> signInWithEmailAndStore({
    required String email, 
    required String password, 
    required String storeCode
  }) async {
    try {
      print('🔍 DEBUG: Starting store-aware login for store: $storeCode');
      
      // Step 1: Validate store exists and is active
      // Use RPC function to bypass RLS for store validation
      final storeValidation = await _supabase.rpc('validate_store_for_login', params: {
        'store_code_param': storeCode
      });
      
      print('🔍 DEBUG: Store validation response: $storeValidation');
      
      if (storeValidation == null || storeValidation['valid'] != true) {
        return AuthResult.failure('Mã cửa hàng không tồn tại hoặc đã bị vô hiệu hóa');
      }
      
      final storeData = storeValidation['store_data'] as Map<String, dynamic>;
      print('🔍 DEBUG: Creating Store object from response...');
      final store = Store.fromJson(storeData);
      print('🔍 DEBUG: Store created: ${store.storeName}');
      
      // Step 2: Authenticate user
      print('🔍 DEBUG: Authenticating user with email: $email');
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);

      // CRITICAL: Debug the auth response object
      print('🔍 DEBUG: Auth response session: ${res.session != null ? 'Present' : 'NULL'}');
      if (res.session != null) {
        final session = res.session!;
        print('🔍 DEBUG: Session access token length: ${session.accessToken.length}');
        print('🔍 DEBUG: Session refresh token length: ${session.refreshToken?.length ?? 'NULL'}');
        print('🔍 DEBUG: Session refresh token: ${session.refreshToken?.length != null && session.refreshToken!.length > 20 ? session.refreshToken!.substring(0, 20) : session.refreshToken}...');
        print('🔍 DEBUG: Session expires at: ${session.expiresAt}');
        print('🔍 DEBUG: Session token type: ${session.tokenType}');
      }

      final user = res.user;
      if (user == null) return AuthResult.failure('Email hoặc mật khẩu không đúng');

      print('🔍 DEBUG: User authenticated: ${user.id}');

      // Step 3: Verify user belongs to the specified store
      print('🔍 DEBUG: Checking user store membership...');
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', user.id)
          .eq('store_id', store.id)
          .eq('is_active', true)
          .maybeSingle();
      
      print('🔍 DEBUG: Profile query response: $profileResponse');
      
      if (profileResponse == null) {
        // User exists but doesn't belong to this store or is inactive
        await _supabase.auth.signOut(); // Sign out the authenticated user
        return AuthResult.failure('Tài khoản này không thuộc cửa hàng "${store.storeName}" hoặc đã bị vô hiệu hóa');
      }

      print('🔍 DEBUG: Creating UserProfile object from response...');
      final profile = UserProfile.fromJson(profileResponse);
      print('🔍 DEBUG: Profile created: ${profile.fullName}');

      // Step 4: Create session and set metadata
      await _createOrUpdateSession(user);
      await _updateUserMetadata(user.id, store.id);

      // Step 5: Store context for biometric login
      await _secure.storeLastStoreCode(storeCode);
      await _secure.storeLastStoreId(store.id);
      print('🔍 DEBUG: Stored store context - code: $storeCode, id: ${store.id}');

      // Step 6: Store refresh token for biometric session restoration
      final currentSession = _supabase.auth.currentSession;
      print('🔍 DEBUG: Current session after login - present: ${currentSession != null}');
      if (currentSession != null) {
        print('🔍 DEBUG: Current session access token length: ${currentSession.accessToken.length}');
        print('🔍 DEBUG: Current session refresh token length: ${currentSession.refreshToken?.length ?? 'NULL'}');
        print('🔍 DEBUG: Current session refresh token: ${currentSession.refreshToken?.length != null && currentSession.refreshToken!.length > 20 ? currentSession.refreshToken!.substring(0, 20) : currentSession.refreshToken}...');

        if (currentSession.refreshToken != null) {
          await _secure.storeRefreshToken(currentSession!.refreshToken!);
          print('🔍 DEBUG: Stored refresh token for biometric login');
        } else {
          print('🚨 DEBUG: No refresh token in current session!');
        }
      } else {
        print('🚨 DEBUG: No current session found after login!');
      }

      print('🔍 DEBUG: Login successful!');
      return AuthResult.success(user: user, profile: profile, store: store);
    } on AuthException catch (e) {
      print('🚨 DEBUG: AuthException: ${e.message}');
      if (e.statusCode == 429) {
        final match = RegExp(r"after (\d+) seconds").firstMatch(e.message);
        final seconds = match != null ? match.group(1) : null;
        final msg = seconds != null
            ? 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ${seconds}s.'
            : 'Bạn thao tác quá nhanh. Vui lòng thử lại sau khoảng 1 phút.';
        return AuthResult.failure(msg);
      } else if (e.statusCode == 400 &&
          (e.message.toLowerCase().contains('invalid_credentials') ||
           e.message.toLowerCase().contains('invalid login'))) {
        return AuthResult.failure('Email hoặc mật khẩu không đúng');
      }
      return AuthResult.failure(e.message);
    } catch (e) {
      print('🚨 DEBUG: General Exception: $e');
      print('🚨 DEBUG: Exception type: ${e.runtimeType}');
      
      // If store validation fails due to RLS, try direct approach
      if (e.toString().contains('permission denied') || e.toString().contains('RLS')) {
        print('🔍 DEBUG: RLS issue detected, trying fallback approach...');
        return _signInWithEmailAndStoreFallback(email, password, storeCode);
      }
      
      return AuthResult.failure('Lỗi đăng nhập: ${e.toString()}');
    }
  }

  /// Fallback method for when RLS blocks store validation
  Future<AuthResult> _signInWithEmailAndStoreFallback(
    String email, 
    String password, 
    String storeCode
  ) async {
    try {
      print('🔍 DEBUG: Using fallback authentication method');
      
      // Step 1: Authenticate user first
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      final user = res.user;
      if (user == null) return AuthResult.failure('Email hoặc mật khẩu không đúng');
      
      print('🔍 DEBUG: User authenticated: ${user.id}');

      // Step 2: Get user profile (now we have RLS context)
      final profileResponse = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('id', user.id)
          .eq('is_active', true)
          .single();
      
      print('🔍 DEBUG: Profile found: ${profileResponse}');
      final profile = UserProfile.fromJson(profileResponse);

      // Step 3: Get store info and validate store code
      final storeResponse = await _supabase
          .from('stores')
          .select('*')
          .eq('id', profile.storeId)
          .eq('is_active', true)
          .single();
      
      print('🔍 DEBUG: Store found: ${storeResponse}');
      final store = Store.fromJson(storeResponse);
      
      // Step 4: Validate store code matches
      if (store.storeCode.toLowerCase() != storeCode.toLowerCase()) {
        await _supabase.auth.signOut(); // Sign out the authenticated user
        return AuthResult.failure('Mã cửa hàng không khớp với tài khoản này');
      }

      // Step 5: Create session and set metadata
      await _createOrUpdateSession(user);
      await _updateUserMetadata(user.id, store.id);

      // Step 6: Store context for biometric login
      await _secure.storeLastStoreCode(storeCode);
      await _secure.storeLastStoreId(store.id);
      print('🔍 DEBUG: Stored store context (fallback) - code: $storeCode, id: ${store.id}');

      // Step 7: Store refresh token for biometric session restoration
      final currentSession = _supabase.auth.currentSession;
      if (currentSession?.refreshToken != null) {
        await _secure.storeRefreshToken(currentSession!.refreshToken!);
        print('🔍 DEBUG: Stored refresh token for biometric login (fallback)');
      }

      print('🔍 DEBUG: Fallback login successful!');
      return AuthResult.success(user: user, profile: profile, store: store);
    } catch (e) {
      print('🚨 DEBUG: Fallback method also failed: $e');
      return AuthResult.failure('Không thể xác thực với cửa hàng này: ${e.toString()}');
    }
  }

  /// Enable biometric authentication for current user
  Future<AuthResult> enableBiometric() async {
    try {
      print('🔍 DEBUG: Enabling biometric authentication');

      // Step 1: Check if biometric is available
      final isAvailable = await BiometricService.isAvailable();
      if (!isAvailable) {
        return AuthResult.failure('Thiết bị không hỗ trợ sinh trắc học');
      }

      // Step 2: Check if user is logged in and has valid session
      final currentSession = _supabase.auth.currentSession;
      print('🔍 DEBUG: Current session user: ${currentSession?.user?.id ?? 'NO SESSION'}');
      print('🔍 DEBUG: Current session has refresh token: ${currentSession?.refreshToken != null}');

      if (currentSession?.refreshToken == null) {
        return AuthResult.failure('Vui lòng đăng nhập trước khi kích hoạt sinh trắc học');
      }

      final refreshToken = currentSession!.refreshToken!;
      print('🔍 DEBUG: Refresh token length: ${refreshToken.length}');
      print('🔍 DEBUG: Refresh token preview: ${refreshToken.length > 20 ? refreshToken.substring(0, 20) : refreshToken}...');

      // WORKAROUND: Handle Supabase refresh token issue
      if (refreshToken.length < 50) {
        print('🚨 DEBUG: SUPABASE REFRESH TOKEN ISSUE - Got ${refreshToken.length} chars instead of JWT');
        print('🔍 DEBUG: Implementing fallback strategy - store credentials for biometric re-auth');

        // Instead of using corrupted refresh token, store encrypted credentials
        final currentUser = currentSession.user;
        final userId = currentUser.id;

        // Get current store info from secure storage (stored during login)
        final storeCode = await _secure.getLastStoreCode();
        final storeId = await _secure.getLastStoreId();

        if (storeCode == null || storeId == null) {
          return AuthResult.failure(
            'Không tìm thấy thông tin cửa hàng.\n\n'
            'Vui lòng đăng nhập lại để thiết lập Face ID.'
          );
        }

        print('🔍 DEBUG: Using fallback - store user context for biometric re-auth');

        // Store user context for biometric re-authentication (no password stored!)
        final biometricPayload = {
          'user_id': userId,
          'email': currentUser.email,
          'store_code': storeCode,
          'store_id': storeId,
          'enabled_at': DateTime.now().toIso8601String(),
        };

        // Step 3: Test biometric authentication
        print('🔍 DEBUG: Triggering biometric authentication...');
        final biometricOk = await BiometricService.authenticate(
          reason: 'Xác thực sinh trắc học để kích hoạt đăng nhập Face ID',
        );

        print('🔍 DEBUG: Biometric authentication result: $biometricOk');
        if (!biometricOk) {
          return AuthResult.failure('Xác thực sinh trắc học không thành công');
        }

        // Store biometric context instead of refresh token
        await _secure.storeBiometricRefreshToken(
          'FALLBACK:${Uri.encodeComponent(biometricPayload.toString())}'
        );

        // Verify storage immediately
        final storedToken = await _secure.getBiometricRefreshToken();
        print('🔍 DEBUG: Fallback token storage verification: ${storedToken != null ? 'SUCCESS' : 'FAILED'}');

        // Update user profile in database
        final updatedRows = await _supabase
            .from('user_profiles')
            .update({'biometric_enabled': true})
            .eq('id', userId);

        print('🔍 DEBUG: Updated user profile with biometric_enabled = true (fallback mode)');

        return AuthResult.success();
      }

      // Validate JWT format for proper refresh tokens
      final tokenParts = refreshToken.split('.');
      if (tokenParts.length != 3) {
        print('🚨 DEBUG: INVALID JWT FORMAT - Expected 3 parts, got: ${tokenParts.length}');
        return AuthResult.failure(
          'Session token không đúng định dạng JWT.\n\n'
          'Vui lòng đăng nhập lại để có session mới.'
        );
      }

      print('🔍 DEBUG: Refresh token validation passed - JWT format OK');

      // Step 3: Test biometric authentication
      print('🔍 DEBUG: Triggering biometric authentication...');
      final biometricOk = await BiometricService.authenticate(
        reason: 'Xác thực sinh trắc học để kích hoạt đăng nhập Face ID',
      );

      print('🔍 DEBUG: Biometric authentication result: $biometricOk');
      if (!biometricOk) {
        return AuthResult.failure('Xác thực sinh trắc học không thành công');
      }

      // Step 4: Store refresh token with biometric protection
      print('🔍 DEBUG: Storing refresh token with biometric protection...');
      await _secure.storeBiometricRefreshToken(refreshToken);

      // Verify storage immediately
      final storedToken = await _secure.getBiometricRefreshToken();
      print('🔍 DEBUG: Token storage verification: ${storedToken != null ? 'SUCCESS' : 'FAILED'}');
      if (storedToken != null) {
        print('🔍 DEBUG: Stored token matches: ${storedToken == refreshToken}');
      }

      // Step 5: Update user profile in database
      final userId = currentSession.user.id;
      await _supabase
          .from('user_profiles')
          .update({'biometric_enabled': true})
          .eq('id', userId);

      print('🔍 DEBUG: Updated user profile with biometric_enabled = true');

      return AuthResult.success();
    } catch (e) {
      print('🚨 DEBUG: Enable biometric error: $e');
      return AuthResult.failure('Lỗi khi kích hoạt sinh trắc học: ${e.toString()}');
    }
  }

  /// Disable biometric authentication for current user
  Future<AuthResult> disableBiometric() async {
    try {
      print('🔍 DEBUG: Disabling biometric authentication');

      // Step 1: Check if user is logged in
      final currentSession = _supabase.auth.currentSession;
      if (currentSession == null) {
        return AuthResult.failure('Vui lòng đăng nhập trước');
      }

      // Step 2: Delete stored biometric refresh token
      await _secure.deleteBiometricRefreshToken();
      print('🔍 DEBUG: Deleted biometric refresh token');

      // Step 3: Update user profile in database
      final userId = currentSession.user.id;
      await _supabase
          .from('user_profiles')
          .update({'biometric_enabled': false})
          .eq('id', userId);

      print('🔍 DEBUG: Updated user profile with biometric_enabled = false');

      return AuthResult.success();
    } catch (e) {
      print('🚨 DEBUG: Disable biometric error: $e');
      return AuthResult.failure('Lỗi khi tắt sinh trắc học: ${e.toString()}');
    }
  }

  /// Check if biometric authentication is available and enabled for current user
  Future<bool> isBiometricAvailableAndEnabled() async {
    try {
      print('🔍 DEBUG: Checking biometric availability...');

      // Check device capability
      final isAvailable = await BiometricService.isAvailable();
      if (!isAvailable) {
        print('🔍 DEBUG: Device does not support biometric');
        return false;
      }

      // Check if we have stored token (this means user enabled biometric before)
      final hasToken = await _secure.hasBiometricRefreshToken();
      print('🔍 DEBUG: Has stored biometric token: $hasToken');

      return hasToken;
    } catch (e) {
      print('🚨 DEBUG: Check biometric availability error: $e');
      return false;
    }
  }

  /// NEW: Store-aware biometric authentication with secure token restore
  Future<AuthResult> signInWithBiometric() async {
    try {
      print('🔍 DEBUG: Starting biometric authentication with secure token');

      // Step 1: Check if biometric is available
      final isAvailable = await BiometricService.isAvailable();
      if (!isAvailable) {
        return AuthResult.failure('Thiết bị không hỗ trợ sinh trắc học');
      }

      // Step 2: Try to get biometric-protected refresh token (this will trigger Face ID)
      String? biometricRefreshToken;
      try {
        print('🔍 DEBUG: Attempting to get biometric refresh token from secure storage...');
        biometricRefreshToken = await _secure.getBiometricRefreshToken();

        if (biometricRefreshToken == null || biometricRefreshToken.isEmpty) {
          print('🚨 DEBUG: No biometric refresh token found in secure storage');
          return AuthResult.failure(
            'Chưa thiết lập đăng nhập sinh trắc học.\n\n'
            'Vui lòng:\n'
            '• Đăng nhập bằng Email/Mật khẩu\n'
            '• Vào Tài khoản → Kích hoạt Face ID'
          );
        }

        print('🔍 DEBUG: Token length: ${biometricRefreshToken.length}');
        print('🔍 DEBUG: Found biometric refresh token: ${biometricRefreshToken.length > 20 ? biometricRefreshToken.substring(0, 20) : biometricRefreshToken}...');

        // Check if this is a fallback token (due to Supabase refresh token issue)
        if (biometricRefreshToken.startsWith('FALLBACK:')) {
          print('🔍 DEBUG: Found fallback biometric token - using credential re-auth');
          return _signInWithBiometricFallback(biometricRefreshToken);
        }

        // Validate token format (JWT should have 3 parts separated by dots)
        final tokenParts = biometricRefreshToken.split('.');
        if (tokenParts.length != 3) {
          print('🚨 DEBUG: Invalid token format - not a JWT. Parts: ${tokenParts.length}');
          await _secure.deleteBiometricRefreshToken();
          return AuthResult.failure('Token không hợp lệ. Vui lòng đăng nhập lại.');
        }

        print('🔍 DEBUG: Token format validation passed - JWT with ${tokenParts.length} parts');
      } catch (e) {
        print('🔍 DEBUG: Failed to get biometric token (user cancelled or auth failed): $e');
        return AuthResult.failure('Xác thực sinh trắc học không thành công');
      }

      // Step 3: Use refresh token to restore session
      try {
        print('🔍 DEBUG: Attempting to restore session with refresh token...');
        print('🔍 DEBUG: Current Supabase auth state: ${_supabase.auth.currentSession?.user?.id ?? 'No current session'}');

        final response = await _supabase.auth.setSession(biometricRefreshToken);

        print('🔍 DEBUG: setSession response - user: ${response.user?.id}');
        print('🔍 DEBUG: setSession response - session: ${response.session != null ? 'Present' : 'NULL'}');

        if (response.session == null) {
          print('🚨 DEBUG: Session restoration failed - session is null');
          // Token expired or invalid, clear it
          await _secure.deleteBiometricRefreshToken();
          return AuthResult.failure(
            'Phiên đăng nhập đã hết hạn.\n\n'
            'Vui lòng đăng nhập lại và kích hoạt lại sinh trắc học.'
          );
        }

        final session = response.session!;
        print('🔍 DEBUG: Session restored successfully - User ID: ${session.user.id}');
        print('🔍 DEBUG: Session access token: ${session.accessToken.length > 20 ? session.accessToken.substring(0, 20) : session.accessToken}...');

        // Step 3.5: Test auth.uid() context immediately after setSession
        try {
          final authUidTest = await _supabase.from('user_profiles')
            .select('id')
            .eq('id', session.user.id)
            .single();
          print('🔍 DEBUG: auth.uid() context test: SUCCESS - ${authUidTest['id']}');
        } catch (e) {
          print('🚨 DEBUG: auth.uid() context test FAILED: $e');
          print('🚨 DEBUG: This indicates RLS policy blocking access after setSession()');
        }

        // Step 4: Get user profile and store info
        final profile = await getUserProfile(session.user.id);
        if (profile == null) {
          await _supabase.auth.signOut();
          return AuthResult.failure('Không tìm thấy thông tin tài khoản');
        }

        // Step 5: Get store info
        final storeResponse = await _supabase
            .from('stores')
            .select('*')
            .eq('id', profile.storeId)
            .eq('is_active', true)
            .single();

        final store = Store.fromJson(storeResponse);

        // Step 6: Update stored refresh token if it changed
        if (session.refreshToken != null && session.refreshToken != biometricRefreshToken) {
          try {
            await _secure.storeBiometricRefreshToken(session.refreshToken!);
            print('🔍 DEBUG: Updated biometric refresh token');
          } catch (e) {
            print('🔍 DEBUG: Failed to update biometric token: $e');
            // Continue anyway, old token might still work
          }
        }

        // Step 7: Update store context for future use
        await _secure.storeLastStoreCode(store.storeCode);
        await _secure.storeLastStoreId(store.id);

        print('🔍 DEBUG: Biometric login successful');
        return AuthResult.success(user: session.user, profile: profile, store: store);

      } catch (e) {
        print('🚨 DEBUG: Failed to restore session with biometric token: $e');
        print('🚨 DEBUG: Error type: ${e.runtimeType}');

        if (e is AuthException) {
          print('🚨 DEBUG: AuthException - Message: ${e.message}');
          print('🚨 DEBUG: AuthException - StatusCode: ${e.statusCode}');
        }

        if (e.toString().contains('Invalid refresh token') ||
            e.toString().contains('refresh_token_not_found') ||
            e.toString().contains('JWT') ||
            e.toString().contains('expired')) {
          print('🚨 DEBUG: Token-related error detected - clearing biometric token');
          await _secure.deleteBiometricRefreshToken();
          return AuthResult.failure(
            'Token đã hết hạn hoặc không hợp lệ.\n\n'
            'Vui lòng đăng nhập lại và kích hoạt lại sinh trắc học.'
          );
        }

        if (e.toString().contains('permission denied') ||
            e.toString().contains('RLS') ||
            e.toString().contains('row-level security')) {
          print('🚨 DEBUG: RLS/Permission error detected');
          return AuthResult.failure(
            'Lỗi phân quyền truy cập.\n\n'
            'Có thể do cấu hình RLS quá chặt. Vui lòng thử đăng nhập thường.'
          );
        }

        // Generic error - don't clear token in case it's temporary
        return AuthResult.failure(
          'Không thể khôi phục phiên đăng nhập.\n\n'
          'Lỗi: ${e.toString()}\n\n'
          'Vui lòng thử lại hoặc đăng nhập bằng email/mật khẩu.'
        );
      }

    } catch (e) {
      print('🚨 DEBUG: Biometric login error: $e');
      return AuthResult.failure('Lỗi xác thực sinh trắc học: ${e.toString()}');
    }
  }

  /// Fallback biometric authentication when Supabase refresh token is corrupted
  Future<AuthResult> _signInWithBiometricFallback(String fallbackToken) async {
    try {
      print('🔍 DEBUG: Processing fallback biometric authentication');

      // Extract payload from fallback token
      final payloadEncoded = fallbackToken.substring('FALLBACK:'.length);
      final payloadString = Uri.decodeComponent(payloadEncoded);

      print('🔍 DEBUG: Fallback payload: $payloadString');

      // Parse the stored context (simple string parsing for now)
      final payloadRegex = RegExp(r"user_id: ([^,]+), email: ([^,]+), store_code: ([^,]+), store_id: ([^,]+)");
      final match = payloadRegex.firstMatch(payloadString);

      if (match == null) {
        print('🚨 DEBUG: Invalid fallback payload format');
        await _secure.deleteBiometricRefreshToken();
        return AuthResult.failure('Token fallback không hợp lệ. Vui lòng thiết lập lại Face ID.');
      }

      final userId = match.group(1)!;
      final email = match.group(2)!;
      final storeCode = match.group(3)!;
      final storeId = match.group(4)!;

      print('🔍 DEBUG: Parsed fallback data - User: $userId, Store: $storeCode');

      // Trigger biometric authentication
      final biometricOk = await BiometricService.authenticate(
        reason: 'Xác thực sinh trắc học để đăng nhập',
      );

      if (!biometricOk) {
        return AuthResult.failure('Xác thực sinh trắc học không thành công');
      }

      print('🔍 DEBUG: Biometric auth successful, redirecting to normal login...');

      // CRITICAL: For now, redirect user to re-enter password as we can't do password-less auth
      // This is a security limitation - we never store passwords!
      return AuthResult.failure(
        'Face ID authentication đã thành công!\n\n'
        'Do hạn chế kỹ thuật của Supabase, bạn cần nhập lại mật khẩu.\n\n'
        'Email: $email\n'
        'Store: $storeCode\n\n'
        'Vui lòng đăng nhập với thông tin trên.'
      );

    } catch (e) {
      print('🚨 DEBUG: Fallback biometric login error: $e');
      await _secure.deleteBiometricRefreshToken();
      return AuthResult.failure(
        'Lỗi đăng nhập sinh trắc học fallback.\n\n'
        'Vui lòng đăng nhập lại và thiết lập lại Face ID.'
      );
    }
  }

  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String storeCode,
    required String fullName,
    required String storeName,
    String? phone,
  }) async {
    try {
      final res = await _supabase.auth.signUp(email: email, password: password);
      final user = res.user;
      if (user == null) return AuthResult.failure('Tạo tài khoản thất bại');

      // create store
      final storeRow = await _supabase
          .from('stores')
          .insert({
            'store_code': storeCode,
            'store_name': storeName,
            'owner_name': fullName,
            'email': email,
            'phone': phone,
            'created_by': user.id,
            'is_active': true,
          })
          .select()
          .single();
      final store = Store.fromJson(storeRow);

      // create user profile
      final profileRow = await _supabase
          .from('user_profiles')
          .insert({
            'id': user.id,
            'store_id': store.id,
            'full_name': fullName,
            'phone': phone,
            'role': 'OWNER',
            'permissions': {},
            'is_active': true,
          })
          .select()
          .single();
      final profile = UserProfile.fromJson(profileRow);

      await _createOrUpdateSession(user);

      // Set store_id in user metadata for RLS policies
      await _updateUserMetadata(user.id, store.id);

      return AuthResult.success(user: user, profile: profile, store: store);
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  Future<bool> sendPasswordResetOTP(String email) async {
    try {
      await _supabase.rpc('generate_otp_code', params: {
        'target_email': email,
        'token_type_param': 'PASSWORD_RESET',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyOTPAndResetPassword(String email, String otp, String newPassword) async {
    try {
      final isValid = await _supabase.rpc('verify_otp_code', params: {
        'target_email': email,
        'input_token': otp,
      });
      if (isValid == true) {
        await _supabase.auth.updateUser(UserAttributes(password: newPassword));
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      // Clear sensitive data but keep store context AND refresh token for biometric login
      await _secure.delete('remember_email');
      await _secure.setRememberFlag(false);
      // Keep refresh_token, last_store_code and last_store_id for biometric login
      print('🔍 DEBUG: Sign out complete, preserved refresh token and store context for biometric');
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }

  Future<void> clearLastStoreCode() async => _secure.clearLastStoreCode();

  Future<void> _createOrUpdateSession(User user) async {
    final deviceId = await _getDeviceId();
    final info = await _getDeviceInfo();
    await _supabase.from('user_sessions').upsert({
      'user_id': user.id,
      'device_id': deviceId,
      'device_name': info['name'],
      'device_type': info['type'],
      'last_accessed_at': DateTime.now().toIso8601String(),
      'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    }, onConflict: 'user_id,device_id');
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      print('🔍 DEBUG: Getting user profile for userId: $userId');
      print('🔍 DEBUG: Current auth.uid(): ${_supabase.auth.currentUser?.id ?? 'NULL'}');

      final row = await _supabase.from('user_profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      if (row != null) {
        print('🔍 DEBUG: User profile found successfully');
        return UserProfile.fromJson(row);
      } else {
        print('🚨 DEBUG: User profile not found - possible RLS policy issue');
        return null;
      }
    } catch (e) {
      print('🚨 DEBUG: getUserProfile error: $e');
      print('🚨 DEBUG: Error type: ${e.runtimeType}');

      // If RLS policy blocks access, this could be due to setSession timing
      if (e.toString().contains('permission denied') ||
          e.toString().contains('RLS') ||
          e.toString().contains('row-level security')) {
        print('🚨 DEBUG: RLS policy blocked getUserProfile - auth context issue');
      }

      return null;
    }
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    try {
      final android = await plugin.androidInfo;
      return {'name': android.model ?? 'Android', 'type': 'MOBILE'};
    } catch (_) {}
    try {
      final ios = await plugin.iosInfo;
      return {'name': ios.utsname.machine ?? 'iOS', 'type': 'MOBILE'};
    } catch (_) {}
    return {'name': 'Unknown Device', 'type': 'MOBILE'};
  }

  Future<String> _getDeviceId() async {
    // Align with SessionService to make device_id stable across restarts
    final info = DeviceInfoPlugin();
    try {
      final a = await info.androidInfo;
      return 'android-${a.id ?? a.model ?? 'device'}';
    } catch (_) {}
    try {
      final i = await info.iosInfo;
      return 'ios-${i.identifierForVendor ?? i.utsname.machine ?? 'device'}';
    } catch (_) {}
    return 'unknown-device';
  }

  /// Update user metadata with store_id for RLS policies
  Future<void> _updateUserMetadata(String userId, String storeId) async {
    try {
      print('🔍 DEBUG: Updating user metadata - BEFORE session check');
      final sessionBefore = _supabase.auth.currentSession;
      print('🔍 DEBUG: Session BEFORE metadata update - refresh token length: ${sessionBefore?.refreshToken?.length ?? 'NULL'}');

      // AVOID admin.updateUserById() as it invalidates current session!
      // Use regular updateUser() instead which preserves session
      await _supabase.auth.updateUser(
        UserAttributes(data: {'store_id': storeId}),
      );

      print('🔍 DEBUG: Updating user metadata - AFTER session check');
      final sessionAfter = _supabase.auth.currentSession;
      print('🔍 DEBUG: Session AFTER metadata update - refresh token length: ${sessionAfter?.refreshToken?.length ?? 'NULL'}');

      // If session was invalidated, log warning but continue
      if (sessionBefore?.refreshToken?.length != sessionAfter?.refreshToken?.length) {
        print('🚨 DEBUG: WARNING - Session token length changed during metadata update!');
        print('🚨 DEBUG: Before: ${sessionBefore?.refreshToken?.length ?? 'NULL'}, After: ${sessionAfter?.refreshToken?.length ?? 'NULL'}');
      }

    } catch (e) {
      print('🚨 DEBUG: Error updating user metadata: $e');
      // If updateUser fails, we'll rely on BaseService fallback
      print('Warning: Could not set store_id in user metadata - using BaseService fallback');
    }
  }

  /// Assign user to a store (for staff invitation)
  Future<bool> assignUserToStore({
    required String userId,
    required String storeId,
    required String role,
    Map<String, dynamic>? permissions,
  }) async {
    try {
      // Update user profile with new store and role
      await _supabase.from('user_profiles').upsert({
        'id': userId,
        'store_id': storeId,
        'role': role,
        'permissions': permissions ?? {},
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Update user metadata for RLS
      await _updateUserMetadata(userId, storeId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current user's store information
  Future<Store?> getCurrentUserStore() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final profile = await getUserProfile(user.id);
    if (profile?.storeId == null) return null;

    try {
      final storeRow = await _supabase
          .from('stores')
          .select('*')
          .eq('id', profile!.storeId!)
          .single();
      return Store.fromJson(storeRow);
    } catch (e) {
      return null;
    }
  }

  /// Check if user has access to a specific store
  Future<bool> validateStoreAccess(String userId, String storeId) async {
    try {
      final profile = await _supabase
          .from('user_profiles')
          .select('store_id, is_active')
          .eq('id', userId)
          .eq('store_id', storeId)
          .eq('is_active', true)
          .maybeSingle();

      return profile != null;
    } catch (e) {
      return false;
    }
  }

  /// Validates a store code and saves it to secure storage if valid.
  Future<Store?> validateAndSetStore(String storeCode) async {
    try {
      final result = await _supabase.rpc('validate_store_for_login', params: {
        'store_code_param': storeCode
      });

      if (result == null || result['valid'] != true) {
        throw Exception('Mã cửa hàng không hợp lệ hoặc đã bị vô hiệu hóa.');
      }

      final store = Store.fromJson(result['store_data']);

      // Save to secure storage for future sessions
      await _secure.storeLastStoreCode(store.storeCode);
      await _secure.storeLastStoreId(store.id);
      await _secure.storeLastStoreName(store.storeName);

      return store;
    } catch (e) {
      // Re-throw with a more specific message if possible
      if (e is Exception) {
        throw e;
      }
      throw Exception('Lỗi khi xác thực cửa hàng: $e');
    }
  }

  /// Checks if a store code is available.
  Future<Map<String, dynamic>> checkStoreCodeAvailability(String storeCode) async {
    try {
      final result = await _supabase.rpc('check_store_code_availability', params: {
        'p_store_code': storeCode
      });
      return result as Map<String, dynamic>;
    } catch (e) {
      return {
        'isAvailable': false,
        'message': 'Lỗi kiểm tra: ${e.toString()}'
      };
    }
  }
}
