import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Đây là file debug để test biometric authentication issues
// RUN: dart debug_biometric.dart

void main() {
  print('🔍 DEBUG: Starting biometric authentication debugging...');

  debugBiometricIssues();
}

void debugBiometricIssues() {
  print('=== BIOMETRIC DEBUG ANALYSIS ===');
  print('');

  print('1. EXPECTED FLOW:');
  print('   a) User đăng nhập bằng email/password với store_code');
  print('   b) Auth service lấy refresh_token từ Supabase session');
  print('   c) Refresh token được lưu vào Keychain với Face ID protection');
  print('   d) User logout (session cleared nhưng refresh token vẫn còn)');
  print('   e) User mở app lại, Face ID button hiện');
  print('   f) User bấm Face ID → unlock refresh token → setSession() → success');
  print('');

  print('2. POTENTIAL ISSUES:');
  print('   a) hasBiometricRefreshToken() trigger Face ID prompt không cần thiết');
  print('   b) setSession(refreshToken) fail vì RLS policy');
  print('   c) Refresh token format không đúng hoặc expired');
  print('   d) FutureBuilder rebuild issue trong login screen');
  print('   e) Supabase RLS block việc restore session');
  print('');

  print('3. RLS INVESTIGATION:');
  print('   - Check user_profiles table RLS policy');
  print('   - Check stores table RLS policy');
  print('   - Verify auth.uid() context trong setSession()');
  print('   - Check JWT payload sau khi setSession()');
  print('');

  print('4. TOKEN VALIDATION:');
  print('   - JWT should have 3 parts: header.payload.signature');
  print('   - Token không được expired');
  print('   - Token format phải match Supabase requirements');
  print('');

  print('5. LOGGING TO WATCH:');
  print('   - "🔍 DEBUG: Found biometric refresh token" → token exists');
  print('   - "🔍 DEBUG: Token format validation passed" → JWT valid');
  print('   - "🔍 DEBUG: setSession response - session: NULL" → RLS issue');
  print('   - "🚨 DEBUG: AuthException" → detailed error info');
  print('');

  print('6. FIXES APPLIED:');
  print('   ✅ Enhanced debug logging throughout biometric flow');
  print('   ✅ Fixed hasBiometricRefreshToken() to not trigger Face ID');
  print('   ✅ Added JWT format validation');
  print('   ✅ Detailed error classification (token vs RLS vs generic)');
  print('   ✅ Preserve refresh token during signOut()');
  print('');

  print('=== END DEBUG ANALYSIS ===');
}

// Helper function to validate JWT format
bool isValidJWT(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return false;

  // Basic base64 validation
  try {
    for (final part in parts) {
      if (part.isEmpty) return false;
    }
    return true;
  } catch (e) {
    return false;
  }
}

// Helper function to decode JWT payload (without verification)
Map<String, dynamic>? decodeJWTPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    // Decode payload (second part)
    final payload = parts[1];

    // Add padding if needed
    String normalizedPayload = payload;
    while (normalizedPayload.length % 4 != 0) {
      normalizedPayload += '=';
    }

    // This would need proper base64 decoding in real implementation
    print('🔍 DEBUG: JWT payload part: $payload');
    return null; // Simplified for debug script
  } catch (e) {
    print('🚨 DEBUG: Failed to decode JWT: $e');
    return null;
  }
}