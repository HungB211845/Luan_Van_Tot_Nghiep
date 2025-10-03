# Test Plan: POS Price Persistence Fix

## 🐛 ISSUE BEING FIXED:
**After hot restart, POS Screen shows 0 prices until user visits ProductDetailScreen**

## 🔍 ROOT CAUSE ANALYSIS:
1. **Database**: `products.current_selling_price` might be 0 even though `price_history` has valid prices
2. **ProductProvider**: Only syncs price in ProductDetailScreen via `_syncPriceFromHistoryIfNeeded()`
3. **POS Loading**: Loads products directly from DB without price sync, getting 0 values
4. **Cache Miss**: `_currentPrices` cache gets populated with 0 values from DB

## ✅ FIX IMPLEMENTED:

### **1. Enhanced ProductProvider Price Loading**
- **Added**: `_syncPriceFromHistory()` method in ProductProvider
- **Modified**: All product loading methods to sync prices if `current_selling_price = 0`
- **Fixed**: `loadProducts()`, `loadProductsPaginated()`, `loadProductsByCompany()`

```dart
// FIXED: Auto-sync price from history during product loading
for (final product in _products) {
  double finalPrice = product.currentSellingPrice;
  if (finalPrice == 0) {
    finalPrice = await _syncPriceFromHistory(product.id); // Auto-sync!
  }
  _currentPrices[product.id] = finalPrice;
}
```

### **2. Database Debugging & Sync**
- **Created**: `debug_price_loading.sql` to diagnose DB issues
- **Enhanced**: `fix_price_and_stock_sync.sql` with better sync logic
- **Added**: Force sync for products with 0 price but valid price history

## 🧪 TESTING STEPS:

### **Phase 1: Database Verification**
1. **Run Debug Query**: Execute `debug_price_loading.sql` in Supabase SQL Editor
2. **Check Results**: 
   - How many products have `current_selling_price = 0`?
   - Do they have valid prices in `price_history`?
   - Are RPC functions working correctly?
3. **Force Sync**: The debug script will auto-sync prices from history

### **Phase 2: App Testing**

#### **Setup Test Data:**
1. **Pick Test Product**: Choose product that had price update before
2. **Check Database**: Verify it has `current_selling_price > 0` after running debug script
3. **Note Expected Price**: What price should POS show?

#### **Test Hot Restart Issue:**
4. **Open POS**: Navigate to POS Screen
5. **Find Test Product**: Look for the product in POS product list
6. **Check Price**: Should show correct price (not 0) ✅
7. **Hot Restart**: Press Cmd+R (or R in terminal) 
8. **Navigate POS Again**: Go back to POS Screen
9. **Check Price**: Should STILL show correct price (not 0) ✅
10. **Add to Cart**: Verify cart uses correct price ✅

#### **Test Without ProductDetail Visit:**
11. **Fresh Restart**: Close and reopen app completely
12. **Direct to POS**: Go straight to POS (don't visit ProductDetail)
13. **Check Prices**: All products should show correct prices ✅
14. **Add Multiple Products**: Test various products in cart ✅

### **Phase 3: Edge Case Testing**

#### **Test Products with Zero History:**
15. **Find New Product**: Product with no price history
16. **Expected**: Should show 0 (no valid price to sync)
17. **Verify**: POS should show 0, not crash

#### **Test Network Issues:**
18. **Airplane Mode**: Turn on airplane mode
19. **Hot Restart**: Test with no internet
20. **Expected**: Should use cached prices, not crash

## 🎯 SUCCESS CRITERIA:

### **Before Fix:**
- ❌ Hot restart → POS shows 0 prices
- ❌ Must visit ProductDetail to load prices
- ❌ Inconsistent pricing experience

### **After Fix:**
- ✅ Hot restart → POS maintains correct prices
- ✅ Direct POS navigation shows correct prices
- ✅ Price sync happens automatically during product loading
- ✅ Consistent pricing across all screens

## 📊 VERIFICATION CHECKLIST:

### **Database Level:**
- [ ] `debug_price_loading.sql` runs successfully
- [ ] Products with 0 price get synced from price_history
- [ ] RPC functions return consistent values
- [ ] `products_with_details` view shows correct data

### **App Level:**
- [ ] POS shows correct prices immediately after hot restart
- [ ] No need to visit ProductDetail first
- [ ] Cart calculations use correct prices
- [ ] Multiple hot restarts maintain prices

### **Performance:**
- [ ] Price sync doesn't slow down product loading significantly
- [ ] No infinite loops or excessive API calls
- [ ] Graceful handling of missing price history
- [ ] Error logging for debugging

## 🚨 ROLLBACK PLAN:

If issues occur:
1. **Revert ProductProvider**: Remove `_syncPriceFromHistory()` calls
2. **Restore Original**: Use old product loading logic
3. **Database Rollback**: Restore `current_selling_price` from backup if needed

## 📝 DEBUG QUERIES:

```sql
-- Check if fix is working
SELECT name, current_selling_price, 
       (SELECT new_price FROM price_history ph 
        WHERE ph.product_id = p.id 
        ORDER BY changed_at DESC LIMIT 1) as latest_history
FROM products p 
WHERE is_active = true AND current_selling_price = 0;

-- Should return 0 rows if fix worked
```

---
**Expected Result: POS prices persist correctly after hot restart without requiring ProductDetail visit!** 🎯