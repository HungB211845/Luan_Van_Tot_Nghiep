import 'package:flutter/material.dart';
import 'core/app/app_widget.dart';
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Chỉ init Supabase - không làm gì khác
  await SupabaseConfig.initialize();
  
  runApp(const AppWidget());
}