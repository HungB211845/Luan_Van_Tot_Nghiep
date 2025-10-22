import '../models/tax_code_lookup_result.dart';

/// In-memory cache for tax code lookup results
///
/// Features:
/// - 15-minute TTL (Time To Live)
/// - Caches both successful and failed lookups
/// - Automatic cleanup of stale entries
/// - Singleton pattern
class TaxCodeLookupCache {
  // Singleton instance
  static final TaxCodeLookupCache _instance = TaxCodeLookupCache._internal();

  factory TaxCodeLookupCache() => _instance;

  TaxCodeLookupCache._internal();

  // Cache storage
  final Map<String, _CacheEntry> _cache = {};

  // Cache TTL
  static const Duration _ttl = Duration(minutes: 15);

  /// Store lookup result in cache
  ///
  /// Accepts null result to cache failed lookups
  /// This prevents repeated API calls for invalid MST
  void set(String taxCode, TaxCodeLookupResult? result) {
    _cache[taxCode] = _CacheEntry(result, DateTime.now());
    _cleanStaleEntries();
  }

  /// Retrieve cached result
  ///
  /// Returns null if:
  /// - Tax code not in cache
  /// - Cache entry expired (> 15 min)
  ///
  /// Note: May return null result (cached failure)
  TaxCodeLookupResult? get(String taxCode) {
    final entry = _cache[taxCode];
    if (entry == null) return null;

    // Check if expired
    if (DateTime.now().difference(entry.timestamp) > _ttl) {
      _cache.remove(taxCode);
      return null;
    }

    return entry.result;
  }

  /// Check if tax code exists in cache (even if failed lookup)
  ///
  /// Returns true if:
  /// - Cache has entry for this tax code
  /// - Entry is not expired
  bool has(String taxCode) {
    final entry = _cache[taxCode];
    if (entry == null) return false;

    // Check if not expired
    if (DateTime.now().difference(entry.timestamp) > _ttl) {
      _cache.remove(taxCode);
      return false;
    }

    return true;
  }

  /// Remove all stale entries from cache
  ///
  /// Called automatically after each set()
  void _cleanStaleEntries() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => now.difference(entry.timestamp) > _ttl);
  }

  /// Clear all cache entries
  ///
  /// Useful for testing or forced refresh
  void clear() => _cache.clear();

  /// Get current cache size
  ///
  /// For debugging purposes
  int get size => _cache.length;

  /// Get cache statistics
  ///
  /// For debugging/monitoring
  Map<String, dynamic> get stats {
    final now = DateTime.now();
    int validEntries = 0;
    int expiredEntries = 0;
    int failedLookups = 0;
    int successfulLookups = 0;

    _cache.forEach((key, entry) {
      if (now.difference(entry.timestamp) > _ttl) {
        expiredEntries++;
      } else {
        validEntries++;
        if (entry.result == null) {
          failedLookups++;
        } else {
          successfulLookups++;
        }
      }
    });

    return {
      'total_entries': _cache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'successful_lookups': successfulLookups,
      'failed_lookups': failedLookups,
      'ttl_minutes': _ttl.inMinutes,
    };
  }
}

/// Internal cache entry class
class _CacheEntry {
  /// Lookup result (null = failed lookup)
  final TaxCodeLookupResult? result;

  /// Timestamp when entry was created
  final DateTime timestamp;

  _CacheEntry(this.result, this.timestamp);
}
