import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // TODO: Chuyển sang .env files
  static const String _url = 'https://paidjvxqwhrlhlfetjqv.supabase.co';
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhaWRqdnhxd2hybGhsZmV0anF2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgyMDA3NzQsImV4cCI6MjA3Mzc3Njc3NH0.T2tmN-D-Y1kJre4Ys-McsKW46615mqEcTgIIz-_yaDA';
  
  static Future<void> initialize() async {
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}