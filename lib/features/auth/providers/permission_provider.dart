import 'package:flutter/foundation.dart';

import '../models/permission.dart';
import '../models/user_profile.dart';

class PermissionProvider extends ChangeNotifier {
  Map<String, bool> _effective = {};
  Map<String, bool> get effective => _effective;

  void applyDefault(UserRole role) {
    final defaults = Permission.defaultPermissions[role] ?? [];
    _effective = {for (final p in defaults) p: true};
    notifyListeners();
  }

  bool has(String permission) => _effective[permission] == true;

  void set(String permission, bool value) {
    _effective[permission] = value;
    notifyListeners();
  }
}
