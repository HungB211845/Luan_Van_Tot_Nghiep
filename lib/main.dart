import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app/app_widget.dart';
import 'core/config/supabase_config.dart';
import 'shared/services/base_service.dart';
import 'services/cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize LRU Cache System
  final cacheManager = CacheManager();
  await cacheManager.initialize();
  
  // Preload essential data for faster app startup (optional)
  if (kReleaseMode) {
    try {
      await cacheManager.preloadEssentialData();
    } catch (e) {
      // Silently fail preload in release mode
      if (kDebugMode) {
        print('Cache preload failed: $e');
      }
    }
  }

  // Set up auth state listener to sync store_id with BaseService
  _setupAuthStateListener();

  // Temporarily set default store ID for backwards compatibility
  BaseService.initializeWithDefaultStore();

  runApp(const AppWidget());
}

/// Listen to auth state changes and sync store_id with BaseService
void _setupAuthStateListener() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final session = data.session;
    final user = session?.user;

    if (user != null) {
      // User logged in - get store_id from metadata
      String? storeId = user.appMetadata?['store_id']?.toString();
      storeId ??= user.userMetadata?['store_id']?.toString();

      if (storeId != null) {
        BaseService.setCurrentUserStoreId(storeId);
      }
    } else {
      // User logged out - clear store_id but keep default for compatibility
      BaseService.setCurrentUserStoreId(null);
    }
  });
}