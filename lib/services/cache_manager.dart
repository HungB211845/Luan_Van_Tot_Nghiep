// =============================================================================
// CACHE MANAGER - QUẢN LÝ CACHE ĐA TẦNG
// =============================================================================

import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:agricultural_pos/features/products/models/product.dart'; 

// Cache entry với expiry time
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration expiry;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > expiry;
  
  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'expiry': expiry.inMilliseconds,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonFunc) {
    return CacheEntry(
      data: fromJsonFunc(json['data']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      expiry: Duration(milliseconds: json['expiry']),
    );
  }
}

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // In-memory cache with LRU eviction (nhanh nhất)
  final Map<String, CacheEntry> _memoryCache = {};
  final Map<String, DateTime> _accessTimes = {};  // Track access times for LRU

  // Cache size limits
  static const int _maxMemoryCacheSize = 100;  // Max 100 entries
  static const int _maxMemorySizeBytes = 5 * 1024 * 1024;  // Max 5MB
  
  // Persistent cache với SharedPreferences
  SharedPreferences? _prefs;
  
  // Cache configurations
  static const Duration _defaultExpiry = Duration(minutes: 5);
  static const Duration _longTermExpiry = Duration(hours: 1);
  static const Duration _shortTermExpiry = Duration(minutes: 1);
  
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // MEMORY CACHE OPERATIONS WITH LRU EVICTION
  void setMemory<T>(String key, T data, {Duration? expiry}) {
    final now = DateTime.now();

    // Check if we need to evict before adding
    _evictIfNeeded();

    _memoryCache[key] = CacheEntry(
      data: data,
      timestamp: now,
      expiry: expiry ?? _defaultExpiry,
    );
    _accessTimes[key] = now;
  }

  T? getMemory<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null || entry.isExpired) {
      _memoryCache.remove(key);
      _accessTimes.remove(key);
      return null;
    }

    // Update access time for LRU
    _accessTimes[key] = DateTime.now();
    return entry.data as T?;
  }

  // PERSISTENT CACHE OPERATIONS
  Future<void> setPersistent<T>(
    String key, 
    T data, 
    Map<String, dynamic> Function(T) toJson,
    {Duration? expiry}
  ) async {
    await initialize();
    
    final entry = CacheEntry(
      data: data,
      timestamp: DateTime.now(),
      expiry: expiry ?? _longTermExpiry,
    );
    
    final jsonData = {
      'data': toJson(data),
      'timestamp': entry.timestamp.millisecondsSinceEpoch,
      'expiry': entry.expiry.inMilliseconds,
    };
    
    await _prefs!.setString(key, jsonEncode(jsonData));
  }

  Future<T?> getPersistent<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    await initialize();
    
    final jsonString = _prefs!.getString(key);
    if (jsonString == null) return null;
    
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(jsonData, (dynamic d) => fromJson(d as Map<String, dynamic>));
      
      if (entry.isExpired) {
        await _prefs!.remove(key);
        return null;
      }
      
      return entry.data;
    } catch (e) {
      // Nếu parse lỗi thì xóa cache bị lỗi
      await _prefs!.remove(key);
      return null;
    }
  }

  // SMART CACHE - TỰ ĐỘNG CHỌN MEMORY HOẶC PERSISTENT
  Future<void> set<T>(
    String key, 
    T data,
    Map<String, dynamic> Function(T) toJson,
    {Duration? expiry, bool persistent = false}
  ) async {
    // Luôn cache vào memory trước (nhanh nhất)
    setMemory(key, data, expiry: expiry);
    
    // Nếu cần persistent thì lưu vào SharedPreferences
    if (persistent) {
      await setPersistent(key, data, toJson, expiry: expiry);
    }
  }

  Future<T?> get<T>(
    String key,
    T Function(dynamic) fromJson,
  ) async {
    // Thử memory cache trước (nhanh nhất)
    final memoryData = getMemory<T>(key);
    if (memoryData != null) {
      _recordCacheHit();
      return memoryData;
    }

    // Initialize if needed
    await initialize();

    // Nếu memory miss thì thử persistent cache
    final jsonString = _prefs?.getString(key);
    if (jsonString != null) {
      try {
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
        final entry = CacheEntry.fromJson(jsonData, fromJson);

        if (!entry.isExpired) {
          // Đưa data từ persistent lên memory cho lần sau
          setMemory(key, entry.data);
          _recordCacheHit();
          return entry.data;
        } else {
          await _prefs!.remove(key);
        }
      } catch (e) {
        await _prefs!.remove(key);
      }
    }

    _recordCacheMiss();
    return null;
  }

  // LRU EVICTION LOGIC
  void _evictIfNeeded() {
    // Remove expired entries first
    _cleanupExpired();

    // If still over limit, remove least recently used
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      _evictLRU();
    }

    // Check memory size (approximate)
    if (_getApproximateMemorySize() > _maxMemorySizeBytes) {
      _evictLRU();
    }
  }

  void _cleanupExpired() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _memoryCache.forEach((key, entry) {
      if (entry.isExpired) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _accessTimes.remove(key);
    }
  }

  void _evictLRU() {
    if (_accessTimes.isEmpty) return;

    // Find least recently used entry
    String? lruKey;
    DateTime? oldestAccess;

    _accessTimes.forEach((key, accessTime) {
      if (oldestAccess == null || accessTime.isBefore(oldestAccess!)) {
        oldestAccess = accessTime;
        lruKey = key;
      }
    });

    if (lruKey != null) {
      _memoryCache.remove(lruKey!);
      _accessTimes.remove(lruKey!);
    }
  }

  int _getApproximateMemorySize() {
    // Rough estimation: each entry ~1KB average
    return _memoryCache.length * 1024;
  }

  // CACHE INVALIDATION
  void invalidateMemory(String key) {
    _memoryCache.remove(key);
    _accessTimes.remove(key);
  }

  Future<void> invalidatePersistent(String key) async {
    await initialize();
    await _prefs!.remove(key);
  }

  Future<void> invalidate(String key) async {
    invalidateMemory(key);
    await invalidatePersistent(key);
  }

  // CLEAR ALL CACHE
  void clearMemory() {
    _memoryCache.clear();
    _accessTimes.clear();
  }

  Future<void> clearPersistent() async {
    await initialize();
    final keys = _prefs!.getKeys().where((key) => key.startsWith('cache_')).toList();
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }

  Future<void> clearAll() async {
    clearMemory();
    await clearPersistent();
  }

  // CACHE PATTERNS CHO CÁC LOẠI DATA KHÁC NHAU
  void invalidatePattern(String pattern) {
    final keysToRemove = _memoryCache.keys
        .where((key) => key.contains(pattern))
        .toList();

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _accessTimes.remove(key);
    }
  }

  // DEBUG INFO WITH LRU STATS
  Map<String, dynamic> getStats() {
    final expiredCount = _memoryCache.values.where((entry) => entry.isExpired).length;
    final approximateSize = _getApproximateMemorySize();

    return {
      'memory_cache_size': _memoryCache.length,
      'memory_cache_keys': _memoryCache.keys.toList(),
      'expired_entries': expiredCount,
      'max_cache_size': _maxMemoryCacheSize,
      'approximate_memory_usage_kb': (approximateSize / 1024).round(),
      'max_memory_size_mb': (_maxMemorySizeBytes / (1024 * 1024)).round(),
      'cache_hit_efficiency': _calculateHitRate(),
    };
  }

  // Cache performance tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;

  double _calculateHitRate() {
    final total = _cacheHits + _cacheMisses;
    return total > 0 ? (_cacheHits / total * 100) : 0.0;
  }

  void _recordCacheHit() {
    _cacheHits++;
  }

  void _recordCacheMiss() {
    _cacheMisses++;
  }

  // PRELOAD CACHE CHO APP STARTUP
  Future<void> preloadEssentialData() async {
    // Implement theo các data cần preload
    // Ví dụ: product categories, dashboard stats...
  }
}

// CACHE KEYS CONSTANTS
class CacheKeys {
  static const String products = 'cache_products';
  static const String productCategories = 'cache_product_categories';
  static const String dashboardStats = 'cache_dashboard_stats';
  static const String customerList = 'cache_customers';
  static const String lowStockProducts = 'cache_low_stock';
  static const String expiringBatches = 'cache_expiring_batches';
  
  // Dynamic keys
  static String productsByCategory(String category) => 'cache_products_$category';
  static String productSearch(String query) => 'cache_search_$query';
  static String customerTransactions(String customerId) => 'cache_customer_transactions_$customerId';
}
