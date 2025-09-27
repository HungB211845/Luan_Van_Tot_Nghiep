import 'package:supabase_flutter/supabase_flutter.dart';
// import '../../features/auth/models/user_profile.dart'; // Comment out temporarily

/// Base service that provides store-aware database operations
/// All business services should extend this to ensure store isolation
abstract class BaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Get current authenticated user's store ID from JWT claims
  /// Returns null if user is not authenticated or has no store
  String? get currentStoreId {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // Try to get store_id from JWT claims first (real auth)
    // Check app_metadata first (preferred for RLS), then user_metadata as fallback
    String? storeId = user.appMetadata?['store_id'] as String?;
    storeId ??= user.userMetadata?['store_id'] as String?;

    if (storeId != null && storeId.isNotEmpty) {
      return storeId;
    }

    // Fallback to cached value for temporary compatibility
    return _currentUserStoreId ?? 'default-store-from-migration';
  }
  
  /// Store ID cache - set by AuthProvider after authentication
  static String? _currentUserStoreId;

  /// Initialize with default store ID from migration
  static void initializeWithDefaultStore() {
    // Temporarily set default store ID from migration until Auth is implemented
    _currentUserStoreId = 'default-store-from-migration';
  }
  
  /// Set current user's store ID (called by AuthProvider)
  static void setCurrentUserStoreId(String? storeId) {
    _currentUserStoreId = storeId;
  }

  /// Get current user's store ID (static access)
  static String? get currentUserStoreId => _currentUserStoreId;

  /// Get default store ID for temporary use until Auth is implemented
  static String getDefaultStoreId() {
    return _currentUserStoreId ?? 'default-store-from-migration';
  }

  /// Get store_id for current user from real auth or fallback
  /// This is a more robust version that works with both auth modes
  String getValidStoreId() {
    final storeId = currentStoreId;
    if (storeId != null && storeId.isNotEmpty) {
      return storeId;
    }

    // If no store_id found, use default (for migration period)
    return getDefaultStoreId();
  }
  
  /// Get current user profile (cached) - Temporarily commented out
  // UserProfile? get currentUserProfile => _currentUserProfile;
  // static UserProfile? _currentUserProfile;

  /// Set current user profile (called by AuthProvider) - Temporarily placeholder
  static void setCurrentUserProfile(dynamic profile) {
    // Temporarily accept any type until UserProfile is fully integrated
    // _currentUserProfile = profile;
  }
  
  /// Protected supabase client access
  SupabaseClient get supabase => _supabase;
  
  /// Ensure user is authenticated and has a store
  void ensureAuthenticated() {
    if (currentStoreId == null) {
      throw Exception('User must be authenticated and belong to a store');
    }
  }
  
  /// Add store_id filter to query builder automatically
  PostgrestFilterBuilder<T> addStoreFilter<T>(PostgrestFilterBuilder<T> query) {
    ensureAuthenticated();
    return query.eq('store_id', currentStoreId!);
  }
  
  /// Add store_id to data automatically for inserts
  Map<String, dynamic> addStoreId(Map<String, dynamic> data) {
    ensureAuthenticated();
    return {
      ...data,
      'store_id': currentStoreId!,
    };
  }
  
  /// Check if current user has permission - Temporarily return true
  bool hasPermission(String permission) {
    // Temporarily return true until Auth system is implemented
    return true;
  }

  /// Enforce permission check - throws if user lacks permission
  void requirePermission(String permission) {
    // Temporarily do nothing until Auth system is implemented
    return;
  }
}