// =============================================================================
// CACHE CONFIGURATION - FEATURE FLAGS & SETTINGS
// =============================================================================

class CacheConfig {
  // Feature Flags - Easy to disable if issues arise
  static const bool enableProductCache = true;
  static const bool enableSearchCache = true;
  static const bool enableStatsCache = false; // DISABLED - table doesn't exist
  static const bool enablePaginationCache = false; // Start conservative
  
  // Cache Timing Configuration
  static const Duration searchCacheExpiry = Duration(minutes: 2);
  static const Duration productCacheExpiry = Duration(minutes: 5);
  static const Duration dashboardCacheExpiry = Duration(minutes: 10);
  static const Duration longTermCacheExpiry = Duration(hours: 1);
  
  // Performance Settings
  static const int maxMemoryCacheSize = 100;
  static const int maxMemorySizeBytes = 5 * 1024 * 1024; // 5MB
  
  // Debug Settings
  static const bool enableCacheLogging = true;
  static const bool enablePerformanceLogging = true;
  
  // Cache Keys Prefix (for easy invalidation)
  static const String cachePrefix = 'agripos_v1';
  
  // Cache effectiveness thresholds
  static const double minHitRateThreshold = 0.4; // 40% minimum hit rate
  static const int minHitsForValidation = 50; // Minimum hits before considering metrics
}

// Cache Performance Metrics with Enhanced Tracking
class CacheMetrics {
  static int totalCacheHits = 0;
  static int totalCacheMisses = 0;
  static int totalCacheOperations = 0;
  
  // Performance timing tracking
  static final List<int> _searchTimes = [];
  static final List<int> _dashboardTimes = [];
  static final Map<String, List<int>> _operationTimes = {};
  
  static double get hitRate {
    final total = totalCacheHits + totalCacheMisses;
    return total > 0 ? (totalCacheHits / total) : 0.0;
  }
  
  static void recordHit() {
    totalCacheHits++;
    totalCacheOperations++;
  }
  
  static void recordMiss() {
    totalCacheMisses++;
    totalCacheOperations++;
  }
  
  /// Record operation timing for performance analysis
  static void recordOperationTime(String operation, int milliseconds) {
    _operationTimes.putIfAbsent(operation, () => []);
    _operationTimes[operation]!.add(milliseconds);
    
    // Keep only last 50 measurements to prevent memory bloat
    if (_operationTimes[operation]!.length > 50) {
      _operationTimes[operation]!.removeRange(0, _operationTimes[operation]!.length - 50);
    }
    
    // Special tracking for key operations
    switch (operation) {
      case 'search':
        _searchTimes.add(milliseconds);
        if (_searchTimes.length > 50) _searchTimes.removeAt(0);
        break;
      case 'dashboard':
        _dashboardTimes.add(milliseconds);
        if (_dashboardTimes.length > 50) _dashboardTimes.removeAt(0);
        break;
    }
  }
  
  /// Get performance statistics for an operation
  static Map<String, dynamic> getOperationStats(String operation) {
    final times = _operationTimes[operation] ?? [];
    if (times.isEmpty) {
      return {'count': 0, 'avg': 0, 'min': 0, 'max': 0};
    }
    
    final avg = times.reduce((a, b) => a + b) / times.length;
    final min = times.reduce((a, b) => a < b ? a : b);
    final max = times.reduce((a, b) => a > b ? a : b);
    
    return {
      'count': times.length,
      'avg': avg.round(),
      'min': min,
      'max': max,
      'recent_avg': times.length > 10 
          ? (times.sublist(times.length - 10).reduce((a, b) => a + b) / 10).round()
          : avg.round(),
    };
  }
  
  static Map<String, dynamic> getStats() {
    return {
      'hit_rate': hitRate,
      'total_hits': totalCacheHits,
      'total_misses': totalCacheMisses,
      'total_operations': totalCacheOperations,
      'is_effective': hitRate >= CacheConfig.minHitRateThreshold && 
                      totalCacheOperations >= CacheConfig.minHitsForValidation,
      'search_performance': getOperationStats('search'),
      'dashboard_performance': getOperationStats('dashboard'),
      'pos_search_performance': getOperationStats('pos_search'),
    };
  }
  
  /// Generate performance report
  static String generatePerformanceReport() {
    final stats = getStats();
    final buffer = StringBuffer();
    
    buffer.writeln('🚀 CACHE PERFORMANCE REPORT');
    buffer.writeln('=' * 40);
    buffer.writeln('Hit Rate: ${(stats['hit_rate'] * 100).toStringAsFixed(1)}%');
    buffer.writeln('Operations: ${stats['total_operations']} (${stats['total_hits']} hits, ${stats['total_misses']} misses)');
    buffer.writeln('Effectiveness: ${stats['is_effective'] ? 'GOOD' : 'NEEDS IMPROVEMENT'}');
    
    // Search performance
    final searchStats = stats['search_performance'] as Map<String, dynamic>;
    if (searchStats['count'] > 0) {
      buffer.writeln('\n🔍 SEARCH PERFORMANCE:');
      buffer.writeln('  Average: ${searchStats['avg']}ms');
      buffer.writeln('  Recent Average: ${searchStats['recent_avg']}ms');
      buffer.writeln('  Range: ${searchStats['min']}ms - ${searchStats['max']}ms');
      buffer.writeln('  Samples: ${searchStats['count']}');
    }
    
    // Dashboard performance
    final dashStats = stats['dashboard_performance'] as Map<String, dynamic>;
    if (dashStats['count'] > 0) {
      buffer.writeln('\n📊 DASHBOARD PERFORMANCE:');
      buffer.writeln('  Average: ${dashStats['avg']}ms');
      buffer.writeln('  Recent Average: ${dashStats['recent_avg']}ms');
      buffer.writeln('  Range: ${dashStats['min']}ms - ${dashStats['max']}ms');
      buffer.writeln('  Samples: ${dashStats['count']}');
    }
    
    return buffer.toString();
  }
  
  static void reset() {
    totalCacheHits = 0;
    totalCacheMisses = 0;
    totalCacheOperations = 0;
    _operationTimes.clear();
    _searchTimes.clear();
    _dashboardTimes.clear();
  }
}