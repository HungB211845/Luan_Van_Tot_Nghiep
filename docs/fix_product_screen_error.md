# 🔧 Fix Product Screen Error - RLS Views Issue

## 🚨 Problem
Màn hình quản lý sản phẩm bị lỗi:
```
PostgrestException(message: column low_stock_products.store_id does not exist, code: 42703)
```

## 🔍 Root Cause
1. **View `low_stock_products` chưa tồn tại** hoặc chưa có cột `store_id`
2. **ProductService đang apply `addStoreFilter()`** lên view này
3. **RLS policies yêu cầu `store_id`** nhưng view cũ không có

## ✅ Solution Applied

### 1. Created Views Migration
File: `supabase/migrations/2025-09-27_create_views_with_store_id.sql`

**Views được tạo:**
- `products_with_details` - với store_id
- `low_stock_products` - với store_id  
- `purchase_orders_with_details` - với store_id

### 2. Updated ProductService with Fallback
File: `lib/features/products/services/product_service.dart`

**Changes:**
- `getLowStockProducts()` - thêm fallback logic
- `getExpiringBatches()` - thêm fallback logic
- `_getLowStockProductsFallback()` - manual query khi view không có
- `_getExpiringBatchesFallback()` - manual query cho expiring batches

## 🚀 Deployment Steps

### Step 1: Run Views Migration
```sql
-- Copy content from: supabase/migrations/2025-09-27_create_views_with_store_id.sql
-- Run in Supabase SQL Editor
```

### Step 2: Verify Views Created
```sql
-- Check if views exist with store_id
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'low_stock_products' 
AND column_name = 'store_id';

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'products_with_details' 
AND column_name = 'store_id';
```

### Step 3: Test App
- Restart app
- Navigate to Product Management screen
- Should load without errors now

## 🔧 Fallback Logic

### Low Stock Products
```dart
// Try view first
final response = await addStoreFilter(_supabase
    .from('low_stock_products')
    .select('*'))
    .order('current_stock', ascending: true);

// Fallback to manual query if view fails
final response = await addStoreFilter(_supabase
    .from('products_with_details')
    .select('id, name, sku, category, min_stock_level, available_stock, company_name, is_active'))
    .eq('is_active', true);
```

### Expiring Batches
```dart
// Try RPC first
final response = await _supabase.rpc('get_expiring_batches_report', params: {'p_months': months});

// Fallback to manual query
final response = await addStoreFilter(_supabase
    .from('product_batches')
    .select('*, products(name, sku)'))
    .eq('is_available', true)
    .not('expiry_date', 'is', null);
```

## 🎯 Expected Results

### Before Fix
- ❌ Product screen crashes with RLS error
- ❌ Cannot load product list
- ❌ Dashboard stats fail

### After Fix
- ✅ Product screen loads normally
- ✅ Low stock products display correctly
- ✅ Dashboard stats work
- ✅ Graceful fallback if views missing

## 🔍 Debug Commands

```sql
-- Check if views exist
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('low_stock_products', 'products_with_details', 'expiring_batches');

-- Check view definitions
SELECT definition 
FROM pg_views 
WHERE viewname = 'low_stock_products';

-- Test view access with RLS
SELECT * FROM low_stock_products LIMIT 1;
```

```dart
// Debug in app
print('Current Store ID: ${BaseService.currentUserStoreId}');
print('Auth User: ${Supabase.instance.client.auth.currentUser?.id}');
print('JWT Store ID: ${Supabase.instance.client.auth.currentUser?.appMetadata?['store_id']}');
```

## 📝 Notes

1. **Views inherit RLS** from underlying tables automatically
2. **Fallback logic** ensures app works even if views are missing
3. **Performance impact** minimal - fallback only triggers on error
4. **Future-proof** - can add more views without breaking existing code

## ✅ Verification Checklist

- [ ] Migration file created
- [ ] Views migration run in Supabase
- [ ] ProductService updated with fallbacks
- [ ] App tested - product screen loads
- [ ] Dashboard stats work
- [ ] No console errors
- [ ] Low stock products display correctly
