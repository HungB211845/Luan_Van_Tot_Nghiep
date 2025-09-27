import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_session.dart';

class SessionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<UserSession>> getUserSessions(String userId) async {
    final res = await _supabase
        .from('user_sessions')
        .select()
        .eq('user_id', userId)
        .order('last_accessed_at', ascending: false);
    return (res as List).map((e) => UserSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> revokeSession(String sessionId) async {
    await _supabase.from('user_sessions').delete().eq('id', sessionId);
  }

  Future<void> revokeAllOtherSessions(String currentDeviceId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    await _supabase.from('user_sessions').delete().eq('user_id', uid).neq('device_id', currentDeviceId);
  }

  Future<void> updateFCMToken(String fcmToken) async {
    final deviceId = await _getDeviceId();
    await _supabase.from('user_sessions').update({'fcm_token': fcmToken}).eq('device_id', deviceId);
  }

  Future<bool> validateSession() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final deviceId = await _getDeviceId();
    final row = await _supabase
        .from('user_sessions')
        .select('expires_at')
        .eq('user_id', user.id)
        .eq('device_id', deviceId)
        .maybeSingle();
    if (row == null) return false;
    final expiresAt = DateTime.parse(row['expires_at']);
    final now = DateTime.now();
    final valid = now.isBefore(expiresAt);
    if (valid) {
      // Rolling window: extend expiry to 30 days from now, and update last_accessed_at
      await _supabase
          .from('user_sessions')
          .update({
            'last_accessed_at': now.toIso8601String(),
            'expires_at': now.add(const Duration(days: 30)).toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('device_id', deviceId);
    }
    return valid;
  }

  Future<bool> isBiometricEnabledOnThisDevice() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final deviceId = await _getDeviceId();
    final row = await _supabase
        .from('user_sessions')
        .select('is_biometric_enabled')
        .eq('user_id', user.id)
        .eq('device_id', deviceId)
        .maybeSingle();
    if (row == null) return false;
    return (row['is_biometric_enabled'] as bool?) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final deviceId = await _getDeviceId();
    await _supabase
        .from('user_sessions')
        .update({'is_biometric_enabled': enabled, 'last_accessed_at': DateTime.now().toIso8601String()})
        .eq('user_id', user.id)
        .eq('device_id', deviceId);
  }

  Future<String> _getDeviceId() async {
    // Best-effort: compose from device model + identifier; here we fallback to model
    final info = DeviceInfoPlugin();
    try {
      final a = await info.androidInfo;
      return 'android-${a.id ?? a.model ?? 'device'}';
    } catch (_) {}
    try {
      final i = await info.iosInfo;
      return 'ios-${i.identifierForVendor ?? i.utsname.machine ?? 'device'}';
    } catch (_) {}
    return 'unknown-device';
  }
}
