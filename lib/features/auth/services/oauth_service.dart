import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import 'auth_service.dart';

class OAuthService {
  Future<AuthResult> signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.agri.pos://auth-callback',
      );
      // Với PKCE flow, app sẽ được mở lại qua deep link sau khi auth thành công.
      // Ở đây trả về success để UI có thể chờ session change listener.
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  Future<AuthResult> signInWithFacebook() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'io.agri.pos://auth-callback',
      );
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }
}
