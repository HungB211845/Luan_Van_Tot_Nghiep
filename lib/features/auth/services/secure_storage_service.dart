import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _keyRefreshToken = 'refresh_token';
  static const _keyBiometricRefreshToken = 'biometric_refresh_token';
  static const _keyRememberEmail = 'remember_email';
  static const _keyRememberStoreCode = 'remember_store_code';
  static const _keyRememberFlag = 'remember_flag';
  static const _keyLastStoreCode = 'last_store_code';
  static const _keyLastStoreId = 'last_store_id';
  static const _keyLastStoreName = 'last_store_name';

  // NEW: Separate biometric credential storage
  static const _keyBiometricEmail = 'biometric_email';
  static const _keyBiometricPassword = 'biometric_password';
  static const _keyBiometricStoreCode = 'biometric_store_code';
  static const _keyBiometricEnabled = 'biometric_enabled';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Secure storage with biometric access control for Face ID/Touch ID
  // Note: Biometric protection is handled by BiometricService.authenticate() calls
  final FlutterSecureStorage _biometricStorage = const FlutterSecureStorage();

  // Generic helpers
  Future<void> write(String key, String value) async => _storage.write(key: key, value: value);
  Future<String?> read(String key) async => _storage.read(key: key);
  Future<void> delete(String key) async => _storage.delete(key: key);
  Future<void> clearAll() async => _storage.deleteAll();

  // Refresh token (optional, Supabase Flutter tự quản lý session; để dự phòng)
  Future<void> storeRefreshToken(String token) async => write(_keyRefreshToken, token);
  Future<String?> getRefreshToken() async => read(_keyRefreshToken);

  // Remember email and store code
  Future<void> storeRememberedEmail(String email) async => write(_keyRememberEmail, email);
  Future<String?> getRememberedEmail() async => read(_keyRememberEmail);
  Future<void> storeRememberedStoreCode(String storeCode) async => write(_keyRememberStoreCode, storeCode);
  Future<String?> getRememberedStoreCode() async => read(_keyRememberStoreCode);
  Future<void> setRememberFlag(bool remember) async => write(_keyRememberFlag, remember ? '1' : '0');
  Future<bool> getRememberFlag() async => (await read(_keyRememberFlag)) == '1';

  // Store context for biometric login
  Future<void> storeLastStoreCode(String storeCode) async => write(_keyLastStoreCode, storeCode);
  Future<String?> getLastStoreCode() async => read(_keyLastStoreCode);
  Future<void> storeLastStoreId(String storeId) async => write(_keyLastStoreId, storeId);
  Future<String?> getLastStoreId() async => read(_keyLastStoreId);

  // Store name for display on login screen
  Future<void> storeLastStoreName(String storeName) async => write(_keyLastStoreName, storeName);
  Future<String?> getLastStoreName() async => read(_keyLastStoreName);

  Future<void> clearLastStoreCode() async => delete(_keyLastStoreCode);

  // Biometric refresh token storage (Face ID/Touch ID protected)
  Future<void> storeBiometricRefreshToken(String token) async {
    try {
      await _biometricStorage.write(key: _keyBiometricRefreshToken, value: token);
    } catch (e) {
      // If biometric storage fails, fallback to regular storage
      await write('${_keyBiometricRefreshToken}_fallback', token);
      rethrow;
    }
  }

  Future<String?> getBiometricRefreshToken() async {
    try {
      // Try biometric storage first
      return await _biometricStorage.read(key: _keyBiometricRefreshToken);
    } catch (e) {
      // If biometric read fails, try fallback (should not happen in production)
      return await read('${_keyBiometricRefreshToken}_fallback');
    }
  }

  Future<void> deleteBiometricRefreshToken() async {
    try {
      await _biometricStorage.delete(key: _keyBiometricRefreshToken);
      await delete('${_keyBiometricRefreshToken}_fallback'); // cleanup fallback if exists
    } catch (e) {
      // Ignore deletion errors
    }
  }

  Future<bool> hasBiometricRefreshToken() async {
    try {
      // Check if token exists without triggering biometric prompt
      // We check both biometric storage and fallback storage
      final biometricToken = await _biometricStorage.read(key: _keyBiometricRefreshToken);
      if (biometricToken != null && biometricToken.isNotEmpty) {
        return true;
      }

      // Check fallback storage (should not happen in production)
      final fallbackToken = await read('${_keyBiometricRefreshToken}_fallback');
      return fallbackToken != null && fallbackToken.isNotEmpty;
    } catch (e) {
      // If any error occurs, fallback to safe behavior
      return false;
    }
  }

  // NEW: Biometric credential storage (independent of Supabase session tokens)
  Future<void> storeBiometricCredentials({
    required String email,
    required String password,
    required String storeCode,
  }) async {
    await write(_keyBiometricEmail, email);
    await write(_keyBiometricPassword, password);
    await write(_keyBiometricStoreCode, storeCode);
    await write(_keyBiometricEnabled, '1');
  }

  Future<Map<String, String?>> getBiometricCredentials() async {
    return {
      'email': await read(_keyBiometricEmail),
      'password': await read(_keyBiometricPassword),
      'storeCode': await read(_keyBiometricStoreCode),
    };
  }

  Future<bool> isBiometricCredentialsStored() async {
    final enabled = await read(_keyBiometricEnabled);
    if (enabled != '1') return false;

    final credentials = await getBiometricCredentials();
    return credentials['email'] != null &&
           credentials['password'] != null &&
           credentials['storeCode'] != null;
  }

  Future<void> deleteBiometricCredentials() async {
    await delete(_keyBiometricEmail);
    await delete(_keyBiometricPassword);
    await delete(_keyBiometricStoreCode);
    await delete(_keyBiometricEnabled);
  }

  // Biometric payload per user (if needed later)
  Future<void> storeBiometricData(String userId, String encryptedData) async => write('bio_$userId', encryptedData);
  Future<String?> getBiometricData(String userId) async => read('bio_$userId');
}
