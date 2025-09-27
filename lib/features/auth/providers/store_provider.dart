import 'package:flutter/foundation.dart';

import '../models/store.dart';
import '../services/store_service.dart';

class StoreProvider extends ChangeNotifier {
  final StoreService _service = StoreService();

  Store? _store;
  bool _isLoading = false;

  Store? get store => _store;
  bool get isLoading => _isLoading;

  Future<void> loadByCode(String code) async {
    _isLoading = true;
    notifyListeners();
    _store = await _service.getStoreByCode(code);
    _isLoading = false;
    notifyListeners();
  }
}
