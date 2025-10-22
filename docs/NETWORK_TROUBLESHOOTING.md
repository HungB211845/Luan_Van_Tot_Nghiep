# Network Troubleshooting Guide - Supabase Timeout Issues

**Version:** 1.0
**Date:** 2025-10-22
**Issue:** `SocketException: Operation timed out` errors

---

## I. ISSUE IDENTIFICATION

### Symptoms

App shows following errors trong Flutter logs:

```
ClientException with SocketException: Operation timed out (OS Error: Operation timed out, errno = 60)
address = paidjvxqwhrlhlfetjqv.supabase.co
port = 55795, 55798, 55801... (changing)
```

### Affected Operations

Timeouts occur across ALL database operations:
- ❌ RPC function calls (`get_revenue_trend`, `search_transactions_with_items`, etc.)
- ❌ Direct table queries (`products_with_details`, `user_profiles`, etc.)
- ❌ View queries (`expiring_batches`, etc.)

### Root Cause

**THIS IS A NETWORK/CONNECTION ISSUE, NOT A CODE BUG!**

Network timeouts are unrelated to:
- Invoice upgrade code changes
- RPC function implementations
- Database schema changes
- Flutter app logic

---

## II. QUICK DIAGNOSTICS

### Test 1: Network Connectivity

```bash
# Test connection to Supabase
ping paidjvxqwhrlhlfetjqv.supabase.co

# Expected: < 100ms response time
# If timeout → network issue
```

### Test 2: Supabase API Direct Test

```bash
# Test REST API directly
curl -i https://paidjvxqwhrlhlfetjqv.supabase.co/rest/v1/ \
  -H "apikey: YOUR_ANON_KEY"

# Expected: Response trong < 1 second
# If timeout → Supabase connection issue
```

### Test 3: Check Supabase Status

Visit: https://status.supabase.com/

Check for:
- ❌ Ongoing incidents
- ❌ Degraded performance
- ⚠️ Maintenance windows

---

## III. COMMON CAUSES & SOLUTIONS

### Cause 1: Unstable WiFi/Cellular Connection

**Symptoms:**
- Intermittent timeouts
- Works sometimes, fails others
- Timeout after 60 seconds exactly

**Solutions:**

**A. Switch Network:**
```
1. iOS Settings → WiFi
2. Switch to different WiFi network
3. Or switch WiFi ↔️ Cellular
4. Restart app và test
```

**B. Reset Network Settings:**
```
iOS Settings → General → Transfer or Reset iPhone
  → Reset → Reset Network Settings
⚠️ Will forget WiFi passwords
```

**C. Airplane Mode Toggle:**
```
1. Enable Airplane Mode (wait 10s)
2. Disable Airplane Mode
3. Wait for connection to restore
4. Restart app
```

---

### Cause 2: Supabase Free Tier Rate Limiting

**Symptoms:**
- Timeouts after many requests
- Happens when using app heavily
- Multiple parallel requests fail

**Free Tier Limits:**
- 500MB database
- 2GB bandwidth/month
- 50K API requests/month
- **Concurrent connections: Limited**

**Solutions:**

**A. Reduce Concurrent Requests:**

Modify app code để limit parallel requests:

```dart
// In ReportProvider or ProductProvider
// Add request throttling

Future<void> loadData() async {
  // BEFORE: Multiple parallel requests
  // await Future.wait([
  //   _loadRevenue(),
  //   _loadInventory(),
  //   _loadTopProducts(),
  // ]);

  // AFTER: Sequential requests
  await _loadRevenue();
  await _loadInventory();
  await _loadTopProducts();
}
```

**B. Implement Caching:**

```dart
// Add cache layer để reduce API calls
class CachedSupabaseService {
  final Map<String, (DateTime, dynamic)> _cache = {};
  final Duration _cacheDuration = Duration(minutes: 5);

  Future<T> cachedQuery<T>(
    String key,
    Future<T> Function() query,
  ) async {
    if (_cache.containsKey(key)) {
      final (timestamp, data) = _cache[key];
      if (DateTime.now().difference(timestamp) < _cacheDuration) {
        return data as T;
      }
    }

    final result = await query();
    _cache[key] = (DateTime.now(), result);
    return result;
  }
}
```

**C. Upgrade Supabase Plan:**

Consider Pro plan ($25/month) for:
- Unlimited API requests
- 8GB database
- 50GB bandwidth
- Higher concurrent connections
- Better performance

---

### Cause 3: High Latency to Supabase Region

**Symptoms:**
- Consistent slow responses (> 500ms)
- Timeouts during normal usage
- All users affected equally

**Check Region:**

Supabase project hosted ở region nào:
1. Supabase Dashboard → Project Settings → General
2. Check "Region" field
3. Compare với your location

**Recommended Regions for Vietnam:**
- Singapore (Southeast Asia) - **BEST**
- Tokyo (Northeast Asia)
- ~~US East~~ - Too far
- ~~Europe~~ - Too far

**Solutions:**

**A. Increase Timeout in Flutter:**

```dart
// In lib/core/constants/supabase_config.dart or similar
final supabase = SupabaseClient(
  supabaseUrl,
  supabaseAnonKey,
  httpClient: http.Client(), // Custom client
);

// Use custom client với longer timeout
import 'package:http/http.dart' as http;

class TimeoutClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final Duration timeout;

  TimeoutClient({this.timeout = const Duration(seconds: 120)});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }
}

// Use it:
final supabase = SupabaseClient(
  supabaseUrl,
  supabaseAnonKey,
  httpClient: TimeoutClient(timeout: Duration(seconds: 120)),
);
```

**B. Migrate to Closer Region:**

⚠️ **ADVANCED - Requires database migration**

1. Create new Supabase project trong Singapore region
2. Dump existing database
3. Restore to new project
4. Update Flutter app config
5. Test thoroughly

**Only do this if consistently slow across all connections.**

---

### Cause 4: Too Many Background Requests

**Symptoms:**
- App loads many screens simultaneously
- Logs show dozens of parallel requests
- Port numbers increment rapidly

**Solutions:**

**A. Reduce Preloading:**

```dart
// In HomeScreen or main app
// BEFORE: Aggressive preloading
initState() {
  _preloadAllData(); // Loads EVERYTHING
}

// AFTER: Lazy loading
initState() {
  _loadEssentialDataOnly(); // Only critical data
}

void navigateToScreen() {
  // Load screen-specific data WHEN navigating
  _loadScreenData();
}
```

**B. Debounce Search Queries:**

```dart
// In search screens
Timer? _debounceTimer;

void onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(Duration(milliseconds: 500), () {
    _performSearch(query); // Only after user stops typing
  });
}
```

**C. Cancel Unnecessary Requests:**

```dart
// Track and cancel in-flight requests
class MyProvider extends ChangeNotifier {
  CancelToken? _currentRequest;

  Future<void> loadData() async {
    // Cancel previous request if still running
    _currentRequest?.cancel();
    _currentRequest = CancelToken();

    try {
      final data = await _service.getData(_currentRequest);
      // ...
    } catch (e) {
      if (e is! CancelledException) rethrow;
    }
  }
}
```

---

### Cause 5: iOS Network Security Settings

**Symptoms:**
- Timeouts only on iOS (works on Android/Web)
- Happens with specific networks (corporate WiFi, etc.)

**Solutions:**

**A. Check Info.plist:**

Ensure `Info.plist` allows HTTPS:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
  <key>NSExceptionDomains</key>
  <dict>
    <key>supabase.co</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <false/>
      <key>NSIncludesSubdomains</key>
      <true/>
      <key>NSExceptionRequiresForwardSecrecy</key>
      <true/>
    </dict>
  </dict>
</dict>
```

**B. VPN/Firewall:**

Corporate networks may block Supabase:
- Try personal hotspot
- Use VPN to bypass restrictions

---

## IV. MONITORING & LOGGING

### Add Connection Logging

```dart
// In Supabase service layer
class BaseService {
  Future<T> executeQuery<T>(Future<T> Function() query) async {
    final startTime = DateTime.now();
    try {
      final result = await query();
      final duration = DateTime.now().difference(startTime);
      print('✅ Query succeeded in ${duration.inMilliseconds}ms');
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      print('❌ Query failed after ${duration.inMilliseconds}ms: $e');
      rethrow;
    }
  }
}
```

### Track Success Rate

```dart
class NetworkStats {
  static int totalRequests = 0;
  static int successfulRequests = 0;
  static int timeouts = 0;

  static void recordSuccess() {
    totalRequests++;
    successfulRequests++;
  }

  static void recordTimeout() {
    totalRequests++;
    timeouts++;
  }

  static double get successRate =>
      totalRequests > 0 ? successfulRequests / totalRequests : 0;

  static void printStats() {
    print('📊 Network Stats:');
    print('   Total: $totalRequests');
    print('   Success: $successfulRequests');
    print('   Timeouts: $timeouts');
    print('   Success Rate: ${(successRate * 100).toStringAsFixed(1)}%');
  }
}
```

---

## V. TEMPORARY WORKAROUNDS

While investigating root cause:

### Workaround 1: Retry Logic

```dart
Future<T> retryOnTimeout<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration delay = const Duration(seconds: 2),
}) async {
  int attempt = 0;
  while (attempt < maxAttempts) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      if (attempt >= maxAttempts ||
          !e.toString().contains('Operation timed out')) {
        rethrow;
      }
      print('⚠️ Timeout on attempt $attempt, retrying...');
      await Future.delayed(delay);
    }
  }
  throw Exception('Failed after $maxAttempts attempts');
}

// Usage:
final data = await retryOnTimeout(
  () => _supabase.from('products').select(),
);
```

### Workaround 2: Offline Mode

```dart
class OfflineFirstService {
  final LocalDatabase _local;
  final SupabaseService _remote;

  Future<List<Product>> getProducts() async {
    try {
      // Try remote first
      final products = await _remote.getProducts()
        .timeout(Duration(seconds: 5));
      // Save to local
      await _local.saveProducts(products);
      return products;
    } catch (e) {
      // Fallback to local cache
      print('⚠️ Remote failed, using cached data');
      return await _local.getProducts();
    }
  }
}
```

### Workaround 3: Loading Indicators

Improve UX during slow loading:

```dart
class BetterLoadingWidget extends StatelessWidget {
  final String message;
  final Duration timeout;

  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(timeout),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return LoadingWidget(message: message);
        }
        // After timeout, show hint
        return Column(
          children: [
            LoadingWidget(message: message),
            SizedBox(height: 16),
            Text(
              'Đang kết nối... Vui lòng kiểm tra mạng',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        );
      },
    );
  }
}
```

---

## VI. PERFORMANCE OPTIMIZATION

### Database Optimization

**1. Add Indexes:**

```sql
-- Improve query performance
CREATE INDEX IF NOT EXISTS idx_transactions_store_date
  ON transactions(store_id, transaction_date DESC);

CREATE INDEX IF NOT EXISTS idx_products_store_active
  ON products(store_id, is_active);

CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction
  ON transaction_items(transaction_id, store_id);
```

**2. Optimize RPC Functions:**

```sql
-- Use CTEs instead of subqueries
CREATE OR REPLACE FUNCTION get_revenue_trend(...)
RETURNS JSON AS $$
BEGIN
  -- Use WITH clause for better performance
  WITH daily_revenue AS (
    SELECT
      DATE(transaction_date) AS day,
      SUM(total_amount) AS revenue
    FROM transactions
    WHERE store_id = p_store_id
      AND transaction_date >= p_start_date
    GROUP BY DATE(transaction_date)
  )
  SELECT json_agg(daily_revenue ORDER BY day)
  FROM daily_revenue;
END;
$$ LANGUAGE plpgsql;
```

### Flutter App Optimization

**1. Pagination:**

```dart
// Load data in chunks
Future<void> loadProducts({int page = 0, int pageSize = 20}) async {
  final offset = page * pageSize;
  final products = await _supabase
    .from('products')
    .select()
    .range(offset, offset + pageSize - 1);
}
```

**2. Lazy Loading:**

```dart
// Use ListView.builder với lazy loading
ListView.builder(
  itemCount: products.length + 1, // +1 for loading indicator
  itemBuilder: (context, index) {
    if (index == products.length) {
      // Load more when reaching end
      _loadMoreProducts();
      return LoadingIndicator();
    }
    return ProductCard(product: products[index]);
  },
);
```

---

## VII. ESCALATION PATH

If timeouts persist after trying all solutions:

### Step 1: Document Issue

Collect information:
```
1. Network type (WiFi/Cellular/Ethernet)
2. ISP/Carrier name
3. Location (city, country)
4. Supabase project region
5. Frequency (always/sometimes/rarely)
6. Affected operations (all/specific)
7. Time of day (morning/afternoon/evening)
```

### Step 2: Contact Supabase Support

**Free Tier:** Community forum at https://github.com/supabase/supabase/discussions

**Paid Tier:** support@supabase.com

Provide:
- Project ref: `paidjvxqwhrlhlfetjqv`
- Issue description
- Example failed requests (timestamps)
- Network diagnostics output

### Step 3: Consider Alternatives

If Supabase consistently unreliable:

**A. Self-Hosted Supabase:**
- Full control over infrastructure
- No rate limits
- Requires server management

**B. Alternative Backend:**
- Firebase (Google)
- AWS Amplify
- Custom Node.js/PostgreSQL server

---

## VIII. PREVENTION

### Best Practices

**1. Design for Offline:**
- Cache critical data locally
- Sync in background
- Graceful degradation

**2. Monitor Performance:**
- Track request durations
- Alert on high failure rates
- Regular performance audits

**3. Test on Real Networks:**
- Test on slow 3G
- Test on public WiFi
- Test on corporate networks

**4. User Feedback:**
- Show loading states
- Explain delays
- Provide manual retry options

---

## IX. RELATED ISSUES

**Network timeouts are unrelated to:**

✅ Invoice upgrade implementation
✅ RPC function code changes
✅ Database migration
✅ Flutter app logic
✅ Model serialization

**Network timeouts ARE related to:**

❌ Internet connection stability
❌ Supabase infrastructure
❌ Rate limiting
❌ Regional latency
❌ Concurrent request limits

---

## X. SUCCESS CRITERIA

Issue is resolved when:

- [ ] < 5% request timeout rate
- [ ] Average response time < 500ms
- [ ] No user complaints about slow loading
- [ ] App usable on slow networks (3G)
- [ ] Graceful degradation works

---

## XI. QUICK REFERENCE

**Immediate Actions (Priority Order):**

1. **Switch network** (WiFi ↔️ Cellular)
2. **Restart app**
3. **Check Supabase status** (https://status.supabase.com)
4. **Wait 5 minutes** (rate limit cooldown)
5. **Try again**

**Long-term Solutions:**

1. Increase timeout values
2. Implement caching
3. Reduce concurrent requests
4. Add retry logic
5. Consider Pro plan upgrade

---

**Troubleshooting Guide Version:** 1.0
**Last Updated:** 2025-10-22
**Issue Type:** Network/Infrastructure
**Severity:** Medium (affects UX, not critical bug)
