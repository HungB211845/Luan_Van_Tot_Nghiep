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
      if (currentSession?.refreshToken != null) {
        await _secure.storeRefreshToken(currentSession!.refreshToken!);
        print('🔍 DEBUG: Stored refresh token for biometric login');
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

  /// NEW: Store-aware biometric authentication
  Future<AuthResult> signInWithBiometric() async {
    try {
      print('🔍 DEBUG: Starting biometric authentication');

      // Step 1: Check if biometric is available
      final isAvailable = await BiometricService.isAvailable();
      if (!isAvailable) {
        return AuthResult.failure('Thiết bị không hỗ trợ xác thực sinh trắc học');
      }

      // Step 2: Get last stored store context
      final lastStoreCode = await _secure.getLastStoreCode();
      print('🔍 DEBUG: Retrieved stored store code: $lastStoreCode');
      if (lastStoreCode == null) {
        return AuthResult.failure('Chưa có thông tin cửa hàng. Vui lòng đăng nhập bằng email/password trước.');
      }

      print('🔍 DEBUG: Found stored store code: $lastStoreCode');

      // Step 3: Validate store still exists and is active (simplified for biometric)
      // Skip RPC validation to avoid RLS issues, just get basic store info
      print('🔍 DEBUG: Skipping RPC validation for biometric flow');

      // We'll validate store access after authentication

      // Step 4: Perform biometric authentication
      final biometricOk = await BiometricService.authenticate(
        reason: 'Xác thực bằng Face/Touch ID để đăng nhập vào cửa hàng $lastStoreCode',
      );

      if (!biometricOk) {
        return AuthResult.failure('Xác thực sinh trắc học không thành công');
      }

      print('🔍 DEBUG: Biometric authentication successful');

      // Step 5: Check if we have an existing session
      final session = _supabase.auth.currentSession;
      if (session != null) {
        print('🔍 DEBUG: Found existing session, validating...');
        // Validate existing session
        final sessionService = SessionService();
        final valid = await sessionService.validateSession();
        if (valid) {
          print('🔍 DEBUG: Session is valid, getting user profile...');
          // Get user profile and store info
          final profile = await getUserProfile(session.user.id);
          if (profile != null) {
            // Get store info
            try {
              final storeResponse = await _supabase
                  .from('stores')
                  .select('*')
                  .eq('id', profile.storeId)
                  .eq('store_code', lastStoreCode)
                  .eq('is_active', true)
                  .single();

              final store = Store.fromJson(storeResponse);
              print('🔍 DEBUG: Using existing valid session with store: ${store.storeName}');
              return AuthResult.success(user: session.user, profile: profile, store: store);
            } catch (e) {
              print('🔍 DEBUG: Store validation failed: $e');
              // Store doesn't match, clear stored data
              await _secure.delete('last_store_code');
              await _secure.delete('last_store_id');
              await _supabase.auth.signOut();
              return AuthResult.failure('Cửa hàng không còn tồn tại hoặc không khớp với tài khoản.');
            }
          }
        }
        print('🔍 DEBUG: Session invalid, signing out...');
        // Invalid session, sign out
        await _supabase.auth.signOut();
      }

      print('🔍 DEBUG: No existing session found');

      // Step 6: For biometric login to work, user needs an active session
      // Guide user to login via email/password/store_code which will auto-fill from "remember me"
      return AuthResult.failure(
        'Chưa có phiên đăng nhập hoạt động.\n\n'
        'Để sử dụng sinh trắc học, vui lòng:\n'
        '• Đăng nhập bằng Email/Mật khẩu/Mã cửa hàng\n'
        '• Bật "Ghi nhớ tôi" để tự điền thông tin\n'
        '• Sau đó có thể dùng sinh trắc học trong phiên hiện tại'
      );

    } catch (e) {
      print('🚨 DEBUG: Biometric login error: $e');
      return AuthResult.failure('Lỗi xác thực sinh trắc học: ${e.toString()}');
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
    } catch (_) {}
  }

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
    final row = await _supabase.from('user_profiles').select('*').eq('id', userId).maybeSingle();
    return row != null ? UserProfile.fromJson(row) : null;
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
      // Set store_id in app_metadata (as expected by get_current_user_store_id function)
      await _supabase.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(
          appMetadata: {'store_id': storeId},
        ),
      );
    } catch (e) {
      // If admin API fails, try using user context update in userMetadata as fallback
      try {
        await _supabase.auth.updateUser(
          UserAttributes(data: {'store_id': storeId}),
        );
      } catch (_) {
        // If both fail, we'll rely on BaseService fallback
        print('Warning: Could not set store_id in user metadata');
      }
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
}
