import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/route_names.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/auth_state.dart';
import '../services/secure_storage_service.dart';
import '../services/session_service.dart';
import '../services/biometric_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _performUnifiedNavigationCheck();
    });
  }

  /// UNIFIED navigation logic - NO race conditions
  /// Check store context FIRST, then session validity
  Future<void> _performUnifiedNavigationCheck() async {
    if (_navigated || !mounted) return;

    print('🔍 DEBUG: Starting unified navigation check...');

    try {
      final secureStorage = SecureStorageService();
      final sessionService = SessionService();

      // STEP 1: SIMPLE store code check - the ONLY check needed
      final hasStoreCode = await secureStorage.hasStoreCode();

      print('🔍 DEBUG: Store code analysis:');
      print('  - Has Store Code: $hasStoreCode');

      // IF no store code, go to StoreCode screen (END HERE)
      if (!hasStoreCode) {
        print('🔍 DEBUG: → StoreCode screen (No store code found)');
        _navigateToAndExit(RouteNames.storeCode);
        return;
      }

      // STEP 2: Store code exists, now check session
      print('🔍 DEBUG: Store code found, checking session...');

      final currentSession = Supabase.instance.client.auth.currentSession;
      print('🔍 DEBUG: Supabase session exists: ${currentSession != null}');

      if (currentSession == null) {
        // No session at all - need to authenticate
        print('🔍 DEBUG: → Login screen (No session)');
        _navigateToAndExit(RouteNames.login);
        return;
      }

      // STEP 3: Session exists, validate it with FAST check first
      final fastSessionIsValid = sessionService.isSupabaseSessionValid();
      print('🔍 DEBUG: Fast Supabase session validation result: $fastSessionIsValid');

      if (!fastSessionIsValid) {
        // Session expired - check biometric credentials for auto-login
        print('🔍 DEBUG: Session expired, checking biometric credentials...');

        final biometricAvailable = await BiometricService.isAvailable();
        final hasBiometricCredentials = await secureStorage.isBiometricCredentialsStored();

        print('🔍 DEBUG: Biometric check for expired session:');
        print('  - Device supports biometric: $biometricAvailable');
        print('  - Has stored credentials: $hasBiometricCredentials');

        if (biometricAvailable && hasBiometricCredentials) {
          print('🔍 DEBUG: → Biometric login screen (Session expired but biometric available)');
          _navigateToAndExit(RouteNames.biometricLogin);
          return;
        }

        // No biometric available, need manual authentication
        print('🔍 DEBUG: → Login screen (Session expired, no biometric)');
        _navigateToAndExit(RouteNames.login);
        return;
      }

      // STEP 4: Session is valid - go directly to Home (skip AuthProvider)
      print('🔍 DEBUG: Session valid, going directly to Home screen...');
      print('🔍 DEBUG: → Home screen (Fast session validation passed - skipping AuthProvider)');
      _navigateToAndExit(RouteNames.homeAlias);
      return;

    } catch (e) {
      print('🚨 DEBUG: Error in navigation check: $e');
      // Safe fallback for any errors
      print('🔍 DEBUG: → Login screen (Error fallback)');
      _navigateToAndExit(RouteNames.login);
    }
  }

  /// Single navigation method with locking to prevent race conditions
  void _navigateToAndExit(String routeName) {
    if (_navigated || !mounted) return;

    print('🔍 DEBUG: FINAL NAVIGATION → $routeName');
    _navigated = true;
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
