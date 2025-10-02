import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void changeTab(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void goToProfile() {
    changeTab(4); // Profile tab is at index 4
  }

  void goToHome() {
    changeTab(0); // Home tab is at index 0
  }

  void goToTransactions() {
    changeTab(1); // Transaction tab is at index 1
  }

  void goToPOS() {
    changeTab(2); // POS tab is at index 2
  }

  void goToProducts() {
    changeTab(3); // Products tab is at index 3
  }
}