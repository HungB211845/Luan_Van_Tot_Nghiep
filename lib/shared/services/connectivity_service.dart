import '../../core/config/supabase_config.dart';

class ConnectivityService {
  static Future<bool> checkSupabaseConnection() async {
    try {
      await SupabaseConfig.client
          .from('_test_connection')
          .select('*')
          .limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}