import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quick_access_item.dart';

class QuickAccessService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get user's quick access configuration
  Future<List<QuickAccessItem>> getConfiguration() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return QuickAccessItem.defaultItems;

      final response = await _supabase
          .from('user_profiles')
          .select('quick_access_config')
          .eq('id', userId)
          .single();

      final config = response['quick_access_config'] as List?;

      if (config == null || config.isEmpty) {
        return QuickAccessItem.defaultItems;
      }

      // Map saved IDs to QuickAccessItem objects
      final items = <QuickAccessItem>[];
      for (final id in config) {
        try {
          final item = QuickAccessItem.availableItems.firstWhere(
            (i) => i.id == id,
          );
          items.add(item);
        } catch (e) {
          // Skip invalid IDs
          continue;
        }
      }

      return items.isEmpty ? QuickAccessItem.defaultItems : items;
    } catch (e) {
      print('Error loading quick access config: $e');
      return QuickAccessItem.defaultItems;
    }
  }

  /// Save user's quick access configuration
  Future<void> saveConfiguration(List<QuickAccessItem> items) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final itemIds = items.map((item) => item.id).toList();

      print('🔧 DEBUG: Saving quick access config for user $userId');
      print('🔧 DEBUG: Item IDs: $itemIds');

      final response = await _supabase
          .from('user_profiles')
          .update({'quick_access_config': itemIds})
          .eq('id', userId)
          .select();

      print('🔧 DEBUG: Update response: $response');
    } catch (e) {
      print('❌ Error saving quick access config: $e');
      rethrow;
    }
  }
}
