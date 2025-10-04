import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../auth/models/store.dart';
import '../../auth/models/user_profile.dart';
import 'secure_storage_service.dart';
// import 'biometric_service.dart'; // COMMENTED OUT: Biometric functionality removed
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

      // Step 5: Store context for future logins
      await _secure.storeLastStoreCode(storeCode);
      await _secure.storeLastStoreId(store.id);
      print('🔍 DEBUG: Stored store context - code: $storeCode, id: ${store.id}');



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
      
      return AuthResult.failure('Lỗi đăng nhập: ${e.toString()}');
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

  /// Securely stores the refresh token for biometric login.
  Future<void> saveRefreshTokenForBiometric(String token) async {
    try {
      await _secure.storeBiometricRefreshToken(token);
      print('🔍 DEBUG: Successfully saved new refresh token for biometric use.');
    } catch (e) {
      print('🚨 DEBUG: Failed to save refresh token for biometric use: $e');
      // Optionally rethrow or handle the error
    }
  }
}
