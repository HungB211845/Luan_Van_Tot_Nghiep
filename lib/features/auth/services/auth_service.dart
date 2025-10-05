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
  final String? prefillEmail;
  final String? prefillStoreCode;

  AuthResult.success({
    this.user,
    this.profile,
    this.store,
    this.prefillEmail,
    this.prefillStoreCode,
  })  : isSuccess = true,
        errorMessage = null;

  AuthResult.failure(this.errorMessage)
      : isSuccess = false,
        user = null,
        profile = null,
        store = null,
        prefillEmail = null,
        prefillStoreCode = null;
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

      // Step 6: Store refresh token for biometric authentication (with validation)
      final currentSession = _supabase.auth.currentSession;
      print('🔍 DEBUG: Current session after login - present: ${currentSession != null}');
      if (currentSession?.accessToken != null) {
        print('🔍 DEBUG: Current session access token length: ${currentSession!.accessToken.length}');
      }
      if (currentSession?.refreshToken != null) {
        print('🔍 DEBUG: Current session refresh token length: ${currentSession!.refreshToken!.length}');
        print('🔍 DEBUG: Current session refresh token: ${currentSession.refreshToken!.length > 20 ? currentSession.refreshToken!.substring(0, 20) : currentSession.refreshToken}...');

        // Validate refresh token before storing for biometric use
        final isValidToken = await isValidRefreshToken(currentSession.refreshToken!);
        if (isValidToken) {
          await _secure.storeRefreshToken(currentSession.refreshToken!);
          print('🔍 DEBUG: Stored valid refresh token for biometric login');
        } else {
          print('🚨 DEBUG: Login session returned invalid refresh token');
        }
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
        // Validate token before storing
        final isValidToken = await isValidRefreshToken(currentSession!.refreshToken!);
        if (isValidToken) {
          await _secure.storeRefreshToken(currentSession.refreshToken!);
          print('🔍 DEBUG: Stored valid refresh token for biometric login (fallback)');
        } else {
          print('🚨 DEBUG: Login session returned invalid refresh token (fallback)');
        }
      }

      print('🔍 DEBUG: Fallback login successful!');
      return AuthResult.success(user: user, profile: profile, store: store);
    } catch (e) {
      print('🚨 DEBUG: Fallback method also failed: $e');
      return AuthResult.failure('Không thể xác thực với cửa hàng này: ${e.toString()}');
    }
  }

  /// Enable biometric authentication with password verification
  Future<AuthResult> enableBiometricWithPassword({
    required String email,
    required String password,
    required String storeCode,
  }) async {
    try {
      print('🔍 DEBUG: Enabling biometric authentication with password verification');
      final isAvailable = await BiometricService.isAvailable();
      if (!isAvailable) return AuthResult.failure('Thiết bị không hỗ trợ sinh trắc học');

      // Verify current credentials by attempting login
      final authResult = await signInWithEmailAndStore(
        email: email,
        password: password,
        storeCode: storeCode,
      );

      if (!authResult.isSuccess) {
        return AuthResult.failure('Thông tin đăng nhập không chính xác');
      }

      final biometricOk = await BiometricService.authenticate(
        reason: 'Xác thực để kích hoạt đăng nhập bằng Face ID',
      );
      if (!biometricOk) return AuthResult.failure('Xác thực sinh trắc học không thành công');

      // Store credentials for future biometric login
      await _secure.storeBiometricCredentials(
        email: email,
        password: password,
        storeCode: storeCode,
      );

      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('user_profiles').update({'biometric_enabled': true}).eq('id', userId);
        print('🔍 DEBUG: Updated user profile with biometric_enabled = true');
      }

      print('🔍 DEBUG: Successfully enabled biometric authentication with credentials');
      return AuthResult.success(profile: authResult.profile, store: authResult.store);
    } catch (e) {
      print('🚨 DEBUG: Enable biometric error: $e');
      return AuthResult.failure('Lỗi khi kích hoạt sinh trắc học: ${e.toString()}');
    }
  }

  /// Enable biometric authentication for current user (legacy method)
  Future<AuthResult> enableBiometric() async {
    return AuthResult.failure('Vui lòng sử dụng enableBiometricWithPassword() để thiết lập Face ID.');
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

      // Step 2: Delete stored biometric credentials
      await _secure.deleteBiometricCredentials();
      print('🔍 DEBUG: Deleted biometric credentials');

      // Step 3: Also delete old biometric refresh token for backward compatibility
      await _secure.deleteBiometricRefreshToken();
      print('🔍 DEBUG: Deleted legacy biometric refresh token');

      // Step 4: Update user profile in database
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

      // Check if we have stored credentials (this means user enabled biometric before)
      final hasCredentials = await _secure.isBiometricCredentialsStored();
      print('🔍 DEBUG: Has stored biometric credentials: $hasCredentials');

      // Also check legacy token storage for backward compatibility
      if (!hasCredentials) {
        final hasToken = await _secure.hasBiometricRefreshToken();
        print('🔍 DEBUG: Has legacy biometric token: $hasToken');
        return hasToken;
      }

      return hasCredentials;
    } catch (e) {
      print('🚨 DEBUG: Check biometric availability error: $e');
      return false;
    }
  }

  /// NEW: Store-aware biometric authentication with credential storage
  Future<AuthResult> signInWithBiometric() async {
    try {
      print('🔍 DEBUG: Starting biometric authentication.');
      final biometricOk = await BiometricService.authenticate(reason: 'Đăng nhập vào AgriPOS');
      if (!biometricOk) return AuthResult.failure('Xác thực sinh trắc học không thành công');

      // Try new credential storage system first
      final hasCredentials = await _secure.isBiometricCredentialsStored();

      if (hasCredentials) {
        print('🔍 DEBUG: Using stored credentials for biometric login');
        final credentials = await _secure.getBiometricCredentials();

        final email = credentials['email'];
        final password = credentials['password'];
        final storeCode = credentials['storeCode'];

        if (email != null && password != null && storeCode != null) {
          // Perform fresh login with stored credentials
          final result = await signInWithEmailAndStore(
            email: email,
            password: password,
            storeCode: storeCode,
          );

          if (result.isSuccess) {
            print('🔍 DEBUG: Biometric login successful with stored credentials');
            return result;
          } else {
            print('🚨 DEBUG: Stored credentials failed, clearing biometric data');
            await _secure.deleteBiometricCredentials();
            return AuthResult.failure('Thông tin đăng nhập đã thay đổi. Vui lòng thiết lập lại Face ID.');
          }
        }
      }

      // FALLBACK: Try legacy token storage for backward compatibility
      print('🔍 DEBUG: Falling back to legacy token storage');
      final storedToken = await _secure.getBiometricRefreshToken();
      if (storedToken == null) {
        return AuthResult.failure('Chưa thiết lập đăng nhập sinh trắc học. Vui lòng đăng nhập bằng mật khẩu.');
      }

      // Try to use the legacy token (this may fail due to Supabase server issues)
      final isValidRefreshToken = await this.isValidRefreshToken(storedToken);
      if (isValidRefreshToken) {
        try {
          final response = await _supabase.auth.setSession(storedToken);
          if (response.session != null) {
            final session = response.session!;
            final profile = await getUserProfile(session.user.id);
            final store = await getCurrentUserStore();

            if (profile != null && store != null) {
              print('🔍 DEBUG: Legacy token login successful');
              return AuthResult.success(user: session.user, profile: profile, store: store);
            }
          }
        } catch (e) {
          print('🚨 DEBUG: Legacy token failed: $e');
        }
      }

      // All methods failed, clear everything
      await _secure.deleteBiometricCredentials();
      await _secure.deleteBiometricRefreshToken();
      return AuthResult.failure('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để thiết lập Face ID.');

    } catch (e) {
      print('🚨 DEBUG: Biometric login error: $e');
      return AuthResult.failure('Lỗi đăng nhập sinh trắc học: ${e.toString()}');
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
      // Clear sensitive data but keep store context, refresh token, biometric credentials AND remember email preferences
      // IMPORTANT: DO NOT clear remember_email or remember_flag - these are user preferences that should persist
      // Keep refresh_token, last_store_code, last_store_id, biometric_credentials, remember_email and remember_flag
      // This preserves Face ID AND Remember Email across logout/login cycles
      print('🔍 DEBUG: Sign out complete, preserved refresh token, store context, biometric credentials AND remember email preferences');
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

  /// Validates if a refresh token has proper JWT format
  Future<bool> isValidRefreshToken(String? token) async {
    if (token == null || token.isEmpty) {
      print('🔍 DEBUG: Token is null or empty');
      return false;
    }

    if (token.length < 50) {
      print('🔍 DEBUG: Token too short (${token.length} chars) - likely corrupted');
      return false;
    }

    // Basic JWT format check (should have 3 parts separated by dots)
    final parts = token.split('.');
    if (parts.length != 3) {
      print('🔍 DEBUG: Token does not have JWT format (${parts.length} parts)');
      return false;
    }

    // CRITICAL: Distinguish between access token and refresh token
    // Access tokens are typically ~900 chars, refresh tokens are much longer
    if (token.length < 200) {
      print('🔍 DEBUG: Token too short for refresh token (${token.length} chars) - likely access token');
      return false;
    }

    print('🔍 DEBUG: Token validation passed (${token.length} chars) - valid refresh token');
    return true;
  }

  /// Clears corrupted session storage and forces fresh authentication
  /// SELECTIVE cleanup - preserves store_code and user preferences
  Future<void> clearCorruptedStorage() async {
    try {
      print('🧹 DEBUG: Starting selective corrupted storage cleanup...');

      // Sign out from Supabase
      await _supabase.auth.signOut();
      print('🧹 DEBUG: Signed out from Supabase');

      // SELECTIVE cleanup - preserve store_code and user preferences
      await _secure.clearSessionDataOnly();
      print('🧹 DEBUG: Cleared session data only (preserved store_code and preferences)');

      print('🧹 DEBUG: Selective corrupted storage cleanup completed');
    } catch (e) {
      print('🚨 DEBUG: Error during selective storage cleanup: $e');
      // Continue anyway, as we want to force a clean state
    }
  }
}
