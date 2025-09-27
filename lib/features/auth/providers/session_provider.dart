import 'package:flutter/foundation.dart';

import '../models/user_session.dart';
import '../services/session_service.dart';

class SessionProvider extends ChangeNotifier {
  final SessionService _service = SessionService();

  List<UserSession> _sessions = [];
  List<UserSession> get sessions => _sessions;

  Future<void> fetchSessions(String userId) async {
    _sessions = await _service.getUserSessions(userId);
    notifyListeners();
  }
}
