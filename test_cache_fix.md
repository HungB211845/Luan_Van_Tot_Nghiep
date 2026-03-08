# 🧪 CACHE STORE ISOLATION FIX - TEST GUIDE

## 🚨 **Root Cause Identified:**

**Store-Aware Cache Isolation Failure** - Cache keys bao gồm `store_$storeId` nhưng khi login/hard reset, store ID không available ngay lập tức → cache keys khác nhau → cache miss → data reset về 0.

## 🔧 **Fixes Applied:**

### **1. Cache Clearing on Auth Events**
- ✅ `AuthProvider.signOut()` - Clear cache before logout
- ✅ `AuthProvider.signInWithStore()` - Clear stale cache before login  
- ✅ `AuthProvider.signInWithBiometric()` - Clear cache before biometric login
- ✅ `AuthProvider.initialize()` - Clear cache on app startup

### **2. Enhanced Cache Key Handling**
- ✅ `CachedProductService._buildCacheKey()` - Handle missing store ID gracefully
- ✅ Fallback to `store_unknown` when store ID missing
- ✅ Add warnings when building keys without valid store

### **3. Store Cache Management**
- ✅ `CachedProductService.clearAllStoreCache()` - Method to clear store-specific cache
- ✅ `ProductProvider.invalidateCache()` - Enhanced to clear store cache

---

## 🧪 **Testing Instructions**

### **Test Case 1: Fresh Login Cache Reset**
```
1. Login với user A (store: ABC) → Products load normally
2. Logout completely 
3. Login với user B (store: XYZ)
4. ✅ EXPECT: Products for store XYZ load (not cached from store ABC)
5. ✅ EXPECT: Stock & prices show correctly (not 0)
6. ✅ EXPECT: No cross-store data leakage
```

### **Test Case 2: Hard Reset / App Restart**
```
1. Use app normally with products showing correct stock/prices
2. Force close app completely (kill process)
3. Restart app → Login
4. ✅ EXPECT: Stock & selling prices load correctly (not 0)
5. ✅ EXPECT: No delay in showing correct data
6. ✅ EXPECT: POS can sell products immediately
```

### **Test Case 3: Device Switch Testing** 
```
1. Login on Device A → Use app normally
2. Login SAME USER on Device B 
3. ✅ EXPECT: Device B shows correct data (not cached from Device A)
4. Logout on Device B
5. Login DIFFERENT USER on Device B
6. ✅ EXPECT: Shows new user's store data (not previous user's data)
```

### **Test Case 4: Cache Key Validation**
```
1. Enable cache logging: CacheConfig.enableCacheLogging = true
2. Login → Check console logs
3. ✅ EXPECT: Cache keys include proper store ID: "cache_products_store_{storeId}"
4. ✅ EXPECT: No "store_unknown" in production usage
5. ✅ EXPECT: Cache HIT rates > 40% after warmup
```

---

## 🔍 **Debug Commands**

### **Enable Debug Logging:**
```dart
// In lib/core/config/cache_config.dart
static const bool enableCacheLogging = true;
static const bool enablePerformanceLogging = true;
```

### **Check Cache Stats:**
```dart
// Add to debug screen or console
final cacheStats = CacheManager().getStats();
print('Cache Stats: $cacheStats');

final performanceReport = CacheMetrics.generatePerformanceReport();  
print(performanceReport);
```

### **Manual Cache Clear:**
```dart
// Emergency cache clear if needed
await CacheManager().clearAll();
await context.read<ProductProvider>().invalidateCache();
```

---

## 🚨 **Critical Validation Points**

### **Store Isolation Verification:**
- [ ] Cache keys ALWAYS include valid store ID 
- [ ] No cache sharing between different stores
- [ ] No "store_unknown" keys in production logs
- [ ] Auth events properly clear old cache

### **Data Consistency Verification:**  
- [ ] Stock never shows 0 when DB has inventory
- [ ] Selling prices show immediately (no 0 → sync delay)
- [ ] POS can sell products right after login
- [ ] Product lists load correctly across app restarts

### **Performance Verification:**
- [ ] Cache hit rate > 40% after app usage
- [ ] No excessive database calls after cache warmup
- [ ] Login/logout performance not degraded
- [ ] Memory usage stable (no cache memory leaks)

---

## 🏆 **Expected Outcomes**

After fixes:

✅ **No more "stock = 0" ghost issues**  
✅ **No more "selling price = 0" reset issues**
✅ **Consistent data across devices & sessions**
✅ **Fast app startup with proper cache isolation**
✅ **No cross-store data contamination**  

---

## 📊 **Success Metrics**

- **Stock Display Accuracy**: 100% (no false zeros)
- **Price Sync Speed**: Immediate (no delays)  
- **Cache Hit Rate**: >40% (performance maintained)
- **Cross-Store Isolation**: 100% (no data leaks)
- **Login/Restart Reliability**: 100% (no cache-related failures)

---

## 🔧 **Rollback Plan**

If issues arise:

```dart
// Disable caching temporarily
class CacheConfig {
  static const bool enableProductCache = false;
  static const bool enableSearchCache = false;
  // This will force direct DB calls until cache fixed
}
```

The app will work normally but with slower performance while cache issues are resolved.