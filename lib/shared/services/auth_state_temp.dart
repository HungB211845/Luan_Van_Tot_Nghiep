// lib/shared/services/auth_state_temp.dart
// TEMPORARY solution cho đến khi implement full Auth system

class AuthStateTemp {
  static final AuthStateTemp _instance = AuthStateTemp._internal();
  factory AuthStateTemp() => _instance;
  AuthStateTemp._internal();

  String? _currentStoreId;

  String? get currentStoreId => _currentStoreId;

  void setCurrentStoreId(String storeId) {
    _currentStoreId = storeId;
  }

  void clear() {
    _currentStoreId = null;
  }

  // Temporary default store ID từ migration
  String get defaultStoreId {
    if (_currentStoreId?.isNotEmpty == true) {
      return _currentStoreId!;
    }
    // Return default store từ migration
    return 'default-store-id'; // Sẽ được replace bằng proper Auth later
  }
}