// =============================================================================
// PERFORMANCE BENCHMARK TOOL - CACHE EFFECTIVENESS TESTING
// =============================================================================

import 'package:flutter/foundation.dart';
import '../../features/products/providers/product_provider.dart';
import '../config/cache_config.dart';

class PerformanceBenchmark {
  static const List<String> testQueries = [
    'thuốc',
    'phân',
    'lúa',
    'bón',
    'NPK',
    'Urea',
    'kali',
    'phospho',
    'diệt cỏ',
    'trừ sâu',
  ];
  
  /// Run comprehensive cache performance benchmarks
  static Future<Map<String, dynamic>> runBenchmarks(ProductProvider provider) async {
    if (kDebugMode) {
      print('🚀 Starting Cache Performance Benchmarks...');
    }
    
    // Reset metrics for clean test
    CacheMetrics.reset();
    
    final results = <String, dynamic>{};
    
    // 1. Search Performance Test
    results['search_benchmark'] = await _testSearchPerformance(provider);
    
    // 2. Dashboard Load Test  
    results['dashboard_benchmark'] = await _testDashboardPerformance(provider);
    
    // 3. Cache Hit Rate Analysis
    results['cache_analysis'] = _analyzeCacheEffectiveness();
    
    // 4. Memory Usage Test
    results['memory_analysis'] = _analyzeMemoryUsage(provider);
    
    if (kDebugMode) {
      print('✅ Benchmarks completed!');
      print(CacheMetrics.generatePerformanceReport());
    }
    
    return results;
  }
  
  /// Test search performance with cache vs without cache
  static Future<Map<String, dynamic>> _testSearchPerformance(ProductProvider provider) async {
    final results = <String, dynamic>{};
    final cachedTimes = <int>[];
    final directTimes = <int>[];
    
    if (kDebugMode) {
      print('🔍 Testing Search Performance...');
    }
    
    // Test cached searches (warm cache)
    for (int i = 0; i < testQueries.length; i++) {
      final query = testQueries[i];
      
      // Cached search
      final stopwatch = Stopwatch()..start();
      await provider.searchProducts(query, useCache: true);
      stopwatch.stop();
      cachedTimes.add(stopwatch.elapsedMilliseconds);
      
      await Future.delayed(const Duration(milliseconds: 100)); // Prevent API flooding
      
      // Direct search (bypass cache)
      final stopwatch2 = Stopwatch()..start();
      await provider.searchProducts(query, useCache: false);
      stopwatch2.stop();
      directTimes.add(stopwatch2.elapsedMilliseconds);
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Calculate statistics
    final cachedAvg = cachedTimes.reduce((a, b) => a + b) / cachedTimes.length;
    final directAvg = directTimes.reduce((a, b) => a + b) / directTimes.length;
    final improvement = ((directAvg - cachedAvg) / directAvg * 100);
    
    results['cached_times'] = cachedTimes;
    results['direct_times'] = directTimes;
    results['cached_avg'] = cachedAvg.round();
    results['direct_avg'] = directAvg.round();
    results['improvement_percent'] = improvement.round();
    results['queries_tested'] = testQueries.length;
    
    if (kDebugMode) {
      print('   Cached avg: ${cachedAvg.round()}ms');
      print('   Direct avg: ${directAvg.round()}ms');
      print('   Improvement: ${improvement.round()}%');
    }
    
    return results;
  }
  
  /// Test dashboard load performance
  static Future<Map<String, dynamic>> _testDashboardPerformance(ProductProvider provider) async {
    final results = <String, dynamic>{};
    final cachedTimes = <int>[];
    final directTimes = <int>[];
    
    if (kDebugMode) {
      print('📊 Testing Dashboard Performance...');
    }
    
    // Test multiple dashboard loads
    for (int i = 0; i < 5; i++) {
      // Cached dashboard load
      final stopwatch = Stopwatch()..start();
      await provider.loadDashboardStats(useCache: true);
      stopwatch.stop();
      cachedTimes.add(stopwatch.elapsedMilliseconds);
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Direct dashboard load
      final stopwatch2 = Stopwatch()..start();
      await provider.loadDashboardStats(useCache: false);
      stopwatch2.stop();
      directTimes.add(stopwatch2.elapsedMilliseconds);
      
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    final cachedAvg = cachedTimes.reduce((a, b) => a + b) / cachedTimes.length;
    final directAvg = directTimes.reduce((a, b) => a + b) / directTimes.length;
    final improvement = ((directAvg - cachedAvg) / directAvg * 100);
    
    results['cached_times'] = cachedTimes;
    results['direct_times'] = directTimes;
    results['cached_avg'] = cachedAvg.round();
    results['direct_avg'] = directAvg.round();
    results['improvement_percent'] = improvement.round();
    results['loads_tested'] = 5;
    
    if (kDebugMode) {
      print('   Cached avg: ${cachedAvg.round()}ms');
      print('   Direct avg: ${directAvg.round()}ms');
      print('   Improvement: ${improvement.round()}%');
    }
    
    return results;
  }
  
  /// Analyze cache effectiveness
  static Map<String, dynamic> _analyzeCacheEffectiveness() {
    final stats = CacheMetrics.getStats();
    
    final effectiveness = <String, dynamic>{
      'hit_rate': stats['hit_rate'],
      'total_operations': stats['total_operations'],
      'is_effective': stats['is_effective'],
      'recommendation': _getPerformanceRecommendation(stats['hit_rate'] as double),
    };
    
    if (kDebugMode) {
      print('📈 Cache Effectiveness: ${(stats['hit_rate'] * 100).toStringAsFixed(1)}%');
    }
    
    return effectiveness;
  }
  
  /// Analyze memory usage patterns
  static Map<String, dynamic> _analyzeMemoryUsage(ProductProvider provider) {
    final memoryStats = provider.getProviderMemoryStats();
    
    return {
      'total_items': memoryStats['total_items'],
      'memory_managed': memoryStats['memory_managed'],
      'auto_cleanup_active': memoryStats['auto_cleanup_active'],
      'memory_efficient': memoryStats['total_items'] < 1000, // Threshold check
    };
  }
  
  /// Get performance recommendation based on hit rate
  static String _getPerformanceRecommendation(double hitRate) {
    if (hitRate >= 0.8) return 'EXCELLENT - Cache is highly effective';
    if (hitRate >= 0.6) return 'GOOD - Cache provides significant benefit';
    if (hitRate >= 0.4) return 'FAIR - Cache provides moderate benefit';
    if (hitRate >= 0.2) return 'POOR - Consider adjusting cache strategy';
    return 'INEFFECTIVE - Cache may need reconfiguration';
  }
  
  /// Simulate user workflow and measure performance
  static Future<Map<String, dynamic>> simulateUserWorkflow(ProductProvider provider) async {
    if (kDebugMode) {
      print('👤 Simulating typical user workflow...');
    }
    
    final workflowTimes = <String, int>{};
    
    // 1. Dashboard load (app startup)
    var stopwatch = Stopwatch()..start();
    await provider.loadDashboardStats(useCache: true);
    stopwatch.stop();
    workflowTimes['dashboard_load'] = stopwatch.elapsedMilliseconds;
    
    // 2. Search for products (multiple searches)
    final searchTimes = <int>[];
    for (final query in testQueries.take(3)) {
      stopwatch = Stopwatch()..start();
      await provider.searchProducts(query, useCache: true);
      stopwatch.stop();
      searchTimes.add(stopwatch.elapsedMilliseconds);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    workflowTimes['search_avg'] = (searchTimes.reduce((a, b) => a + b) / searchTimes.length).round();
    
    // 3. POS search simulation
    final posSearchTimes = <int>[];
    for (final query in ['thu', 'phân', 'lúa']) {
      stopwatch = Stopwatch()..start();
      await provider.quickSearchForPOS(query, useCache: true);
      stopwatch.stop();
      posSearchTimes.add(stopwatch.elapsedMilliseconds);
      await Future.delayed(const Duration(milliseconds: 30));
    }
    workflowTimes['pos_search_avg'] = (posSearchTimes.reduce((a, b) => a + b) / posSearchTimes.length).round();
    
    final totalTime = workflowTimes.values.reduce((a, b) => a + b);
    
    if (kDebugMode) {
      print('   Total workflow time: ${totalTime}ms');
      print('   Dashboard: ${workflowTimes['dashboard_load']}ms');
      print('   Search avg: ${workflowTimes['search_avg']}ms');  
      print('   POS search avg: ${workflowTimes['pos_search_avg']}ms');
    }
    
    return {
      'total_time': totalTime,
      'breakdown': workflowTimes,
      'workflow_rating': _rateWorkflowPerformance(totalTime),
    };
  }
  
  static String _rateWorkflowPerformance(int totalMs) {
    if (totalMs < 500) return 'EXCELLENT - Very responsive';
    if (totalMs < 1000) return 'GOOD - Responsive';
    if (totalMs < 2000) return 'FAIR - Acceptable';
    if (totalMs < 4000) return 'POOR - Sluggish';
    return 'UNACCEPTABLE - Very slow';
  }
}