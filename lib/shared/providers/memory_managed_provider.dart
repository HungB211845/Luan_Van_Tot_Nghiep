// =============================================================================
// MEMORY MANAGED PROVIDER MIXIN - AUTO MEMORY MANAGEMENT
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Mixin provides automatic memory management for providers
/// Includes auto-clear mechanisms, memory tracking, and size limits
mixin MemoryManagedProvider on ChangeNotifier {

  // Memory tracking
  static const int _maxListSize = 1000;  // Max items per list
  static const int _maxMapSize = 500;    // Max items per map
  static const Duration _autoClearInterval = Duration(minutes: 10);
  static const Duration _dataExpiryTime = Duration(hours: 1);

  // Auto-clear timer
  Timer? _autoClearTimer;

  // Track when data was last accessed/updated
  DateTime _lastAccessed = DateTime.now();
  final Map<String, DateTime> _dataTimestamps = {};

  // Memory stats
  int _totalItemsInMemory = 0;

  @override
  void notifyListeners() {
    _lastAccessed = DateTime.now();
    super.notifyListeners();
  }

  /// Initialize memory management (call in provider constructor)
  void initializeMemoryManagement() {
    _startAutoClearTimer();
  }

  /// Start auto-clear timer
  void _startAutoClearTimer() {
    _autoClearTimer?.cancel();
    _autoClearTimer = Timer.periodic(_autoClearInterval, (_) {
      _performAutoClear();
    });
  }

  /// Perform automatic memory cleanup
  void _performAutoClear() {
    final now = DateTime.now();

    // Clear expired data timestamps
    _dataTimestamps.removeWhere((key, timestamp) {
      return now.difference(timestamp) > _dataExpiryTime;
    });

    // If provider hasn't been accessed recently, clear non-essential data
    if (now.difference(_lastAccessed) > _autoClearInterval) {
      clearNonEssentialData();
    }

    // Force memory management if too much data
    if (_totalItemsInMemory > _maxListSize) {
      performMemoryOptimization();
    }
  }

  /// Clear non-essential data (override in provider)
  void clearNonEssentialData() {
    // Override this method in your provider to clear cache, filtered lists, etc.
    if (kDebugMode) {
      print('MemoryManagedProvider: Clearing non-essential data');
    }
  }

  /// Perform memory optimization (override in provider)
  void performMemoryOptimization() {
    // Override this method in your provider for aggressive memory cleanup
    if (kDebugMode) {
      print('MemoryManagedProvider: Performing memory optimization');
    }
  }

  /// Manage list size with automatic truncation
  List<T> managedList<T>(List<T> list, {int? maxSize}) {
    final limit = maxSize ?? _maxListSize;

    if (list.length > limit) {
      // Keep most recent items (assuming chronological order)
      final truncatedList = list.sublist(list.length - limit);

      if (kDebugMode) {
        print('MemoryManagedProvider: Truncated list from ${list.length} to ${truncatedList.length}');
      }

      return truncatedList;
    }

    return list;
  }

  /// Manage map size with LRU eviction
  Map<K, V> managedMap<K, V>(Map<K, V> map, {int? maxSize}) {
    final limit = maxSize ?? _maxMapSize;

    if (map.length > limit) {
      // Simple eviction: remove oldest entries
      final entries = map.entries.toList();
      final keepCount = (limit * 0.8).floor(); // Keep 80% when cleaning

      final newMap = <K, V>{};
      for (int i = entries.length - keepCount; i < entries.length; i++) {
        newMap[entries[i].key] = entries[i].value;
      }

      if (kDebugMode) {
        print('MemoryManagedProvider: Reduced map from ${map.length} to ${newMap.length}');
      }

      return newMap;
    }

    return map;
  }

  /// Update data timestamp for tracking
  void updateDataTimestamp(String key) {
    _dataTimestamps[key] = DateTime.now();
  }

  /// Check if data is expired
  bool isDataExpired(String key) {
    final timestamp = _dataTimestamps[key];
    if (timestamp == null) return true;

    return DateTime.now().difference(timestamp) > _dataExpiryTime;
  }

  /// Update total items count for monitoring
  void updateItemCount(int count) {
    _totalItemsInMemory = count;
  }

  /// Get memory statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'total_items': _totalItemsInMemory,
      'data_timestamps_count': _dataTimestamps.length,
      'last_accessed': _lastAccessed.toIso8601String(),
      'max_list_size': _maxListSize,
      'max_map_size': _maxMapSize,
      'auto_clear_interval_minutes': _autoClearInterval.inMinutes,
    };
  }

  /// Force immediate memory cleanup
  void forceMemoryCleanup() {
    clearNonEssentialData();
    performMemoryOptimization();
    _dataTimestamps.clear();
    _totalItemsInMemory = 0;

    if (kDebugMode) {
      print('MemoryManagedProvider: Forced memory cleanup completed');
    }
  }

  @override
  void dispose() {
    _autoClearTimer?.cancel();
    _dataTimestamps.clear();
    super.dispose();
  }
}

/// Extension methods for easier memory management
extension MemoryManagedList<T> on List<T> {
  /// Auto-truncate list if too large
  List<T> managed({int maxSize = 1000}) {
    if (length > maxSize) {
      return sublist(length - maxSize);
    }
    return this;
  }
}

extension MemoryManagedMap<K, V> on Map<K, V> {
  /// Auto-cleanup map if too large
  Map<K, V> managed({int maxSize = 500}) {
    if (length > maxSize) {
      final entries = this.entries.toList();
      final keepCount = (maxSize * 0.8).floor();

      final newMap = <K, V>{};
      for (int i = entries.length - keepCount; i < entries.length; i++) {
        newMap[entries[i].key] = entries[i].value;
      }
      return newMap;
    }
    return this;
  }
}