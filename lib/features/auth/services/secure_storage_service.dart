import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _keyRefreshToken = 'refresh_token';
  static const _keyRememberEmail = 'remember_email';
  static const _keyRememberFlag = 'remember_flag';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Generic helpers
  Future<void> write(String key, String value) async => _storage.write(key: key, value: value);
  Future<String?> read(String key) async => _storage.read(key: key);
  Future<void> delete(String key) async => _storage.delete(key: key);
  Future<void> clearAll() async => _storage.deleteAll();

  // Refresh token (optional, Supabase Flutter tự quản lý session; để dự phòng)
  Future<void> storeRefreshToken(String token) async => write(_keyRefreshToken, token);
  Future<String?> getRefreshToken() async => read(_keyRefreshToken);

  // Remember email
  Future<void> storeRememberedEmail(String email) async => write(_keyRememberEmail, email);
  Future<String?> getRememberedEmail() async => read(_keyRememberEmail);
  Future<void> setRememberFlag(bool remember) async => write(_keyRememberFlag, remember ? '1' : '0');
  Future<bool> getRememberFlag() async => (await read(_keyRememberFlag)) == '1';

  // Biometric payload per user (if needed later)
  Future<void> storeBiometricData(String userId, String encryptedData) async => write('bio_$userId', encryptedData);
  Future<String?> getBiometricData(String userId) async => read('bio_$userId');
}
