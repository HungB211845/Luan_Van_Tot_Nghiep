# 🔧 Price Sync Fix - Migration Guide

## 📋 Tổng Quan Vấn Đề

### **Vấn đề gốc:**
Luồng cập nhật giá từ **Product Detail Screen → POS Screen** bị gãy do xung đột giữa các migration files:

1. **Migration conflict:** File `20251005120000_fix_views_and_price_sync_logic.sql` đã overwrite function `update_product_selling_price` với signature SAI (có parameter `p_user_id` thừa)
2. **Client-Database mismatch:** ProductService.dart gọi RPC function với 3 params nhưng database function expect 4 params
3. **Price sync failed:** Products hiển thị giá 0 VND vì update giá không thành công
4. **Partial sync logic:** Migration `20251005140000_manual_price_sync_from_history.sql` chỉ sync products có giá = 0, bỏ qua products có giá khác 0

---

## ✅ Giải Pháp Đã Triển Khai

### **1. Xóa Migration File Conflict**
```bash
# Đã xóa file gây conflict
rm supabase/migrations/20251005120000_fix_views_and_price_sync_logic.sql
```

### **2. Tạo Migration Mới (20251005150000_final_price_sync_fix.sql)**

**Nội dung chính:**
- ✅ Drop tất cả variations của function `update_product_selling_price`
- ✅ Recreate function với signature ĐÚNG (3 params: `p_product_id`, `p_new_price`, `p_reason`)
- ✅ Function tự lấy `user_id` từ `auth.uid()` thay vì nhận từ client
- ✅ Fix views: `expiring_batches`, `low_stock_products`
- ✅ Thêm performance indexes

**Function Signature Đúng:**
```sql
CREATE OR REPLACE FUNCTION update_product_selling_price(
    p_product_id uuid,
    p_new_price numeric,
    p_reason text DEFAULT 'Manual price update'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
```

### **3. Update Migration Sync Logic (20251005140000_manual_price_sync_from_history.sql)**

**Thay đổi quan trọng:**
```sql
-- TRƯỚC (sai - chỉ sync products có giá 0):
WHERE p.current_selling_price IS NULL OR p.current_selling_price = 0

-- SAU (đúng - sync TẤT CẢ products có price history):
WHERE p.is_active = true
```

**Kết quả:**
- ✅ Sync TẤT CẢ products có price history về giá mới nhất
- ✅ Verification summary hiển thị số lượng products được sync
- ✅ Warning nếu có products vẫn còn giá 0 sau sync

### **4. Client Code Verification**

**Luồng hoàn chỉnh đã verify:**
1. ✅ **Product Detail Screen** (`product_detail_screen.dart:146`)
   ```dart
   await provider.updateCurrentSellingPrice(
     product.id,
     newPrice,
     reason: 'Cập nhật từ giao diện quản lý sản phẩm',
   )
   ```

2. ✅ **ProductProvider** (`product_provider.dart:1359`)
   ```dart
   final success = await _productService.updateCurrentSellingPrice(
     productId,
     newPrice,
     reason: reason,
   )
   ```

3. ✅ **ProductService** (`product_service.dart:781`)
   ```dart
   await _supabase.rpc('update_product_selling_price', params: {
     'p_product_id': productId,
     'p_new_price': newPrice,
     'p_reason': reason,
   })
   ```

4. ✅ **Database Function** - nhận đúng 3 params, tự lấy user_id từ auth.uid()

### **5. Auto-Sync Fallback Logic**

User đã tự implement fallback trong ProductProvider:
```dart
// product_provider.dart:341-344
double finalPrice = product.currentSellingPrice;
if (finalPrice == 0) {
  finalPrice = await _syncPriceFromHistory(product.id);
}
_currentPrices[product.id] = finalPrice;
```

---

## 🚀 Cách Chạy Migration

### **Bước 1: Run Migration Files theo thứ tự**

```bash
# 1. Run migration fix function signature & views
supabase/migrations/20251005150000_final_price_sync_fix.sql

# 2. Run migration sync prices from history
supabase/migrations/20251005140000_manual_price_sync_from_history.sql
```

**Copy và paste vào Supabase SQL Editor theo thứ tự trên.**

### **Bước 2: Verify Migration Success**

Chạy query này để kiểm tra:
```sql
-- Check function signature
SELECT
    routine_name,
    pg_get_function_arguments(p.oid) as function_signature
FROM information_schema.routines r
JOIN pg_proc p ON r.routine_name = p.proname
WHERE routine_name = 'update_product_selling_price';

-- Check products synced
SELECT
    COUNT(*) FILTER (WHERE current_selling_price > 0) as products_with_price,
    COUNT(*) FILTER (WHERE current_selling_price = 0) as products_zero_price,
    COUNT(*) as total_products
FROM products
WHERE is_active = true;
```

**Expected Results:**
- ✅ Function signature: `p_product_id uuid, p_new_price numeric, p_reason text`
- ✅ Tất cả products có price history phải có `current_selling_price > 0`

### **Bước 3: Rebuild Flutter App**

```bash
# Clean build cache
flutter clean

# Rebuild app
flutter run
```

---

## 🧪 Testing Checklist

### **Test 1: Update Price từ Product Detail Screen**
1. Vào Product Detail Screen của 1 sản phẩm
2. Tap vào giá bán hiện tại để edit
3. Nhập giá mới (ví dụ: 250,000)
4. Tap "Xong" để save
5. **Expected:**
   - ✅ Giá cập nhật thành công
   - ✅ Toast "Cập nhật giá bán thành công" hiển thị
   - ✅ Price history có record mới

### **Test 2: Verify Price trong POS Screen**
1. Vào POS Screen
2. Search sản phẩm vừa update giá
3. **Expected:**
   - ✅ Giá hiển thị đúng (250,000 VND)
   - ✅ Add to cart với giá đúng

### **Test 3: Auto-Sync Price từ History**
1. Tìm 1 product có `current_selling_price = 0` nhưng có price_history
2. Load product trong ProductListScreen
3. **Expected:**
   - ✅ App tự động sync giá từ history
   - ✅ Hiển thị giá mới nhất từ price_history

### **Test 4: Create PO với Selling Price**
1. Tạo Purchase Order mới
2. Thêm product và nhập selling_price
3. Deliver PO và confirm goods receipt
4. **Expected:**
   - ✅ Product's current_selling_price được update
   - ✅ Price history có record với reason "Auto-updated from PO..."

---

## 📊 Migration Files Summary

| File | Status | Purpose |
|------|--------|---------|
| `20251005120000_fix_views_and_price_sync_logic.sql` | ❌ Đã xóa | File conflict với signature SAI |
| `20251005150000_final_price_sync_fix.sql` | ✅ Mới tạo | Fix function signature + views + indexes |
| `20251005140000_manual_price_sync_from_history.sql` | ✅ Đã update | Sync TẤT CẢ products (không chỉ giá 0) |
| `emergency_database_fixes_v2.sql` | ✅ Giữ nguyên | Backup function definition |

---

## ⚠️ Known Issues & Solutions

### **Issue 1: iOS Build Error**
```
DVTDeviceOperation: Encountered a build number "" that is incompatible
```

**Solution:**
```bash
flutter clean
flutter run
```

### **Issue 2: Products vẫn hiển thị 0 VND sau migration**

**Root Causes:**
1. Migration chưa chạy hoặc chạy failed
2. Products không có price_history records

**Solutions:**
```sql
-- Check if products have price history
SELECT p.id, p.name, p.current_selling_price,
       (SELECT COUNT(*) FROM price_history WHERE product_id = p.id) as history_count
FROM products p
WHERE p.current_selling_price = 0 AND p.is_active = true;

-- Manual update if needed
UPDATE products
SET current_selling_price = (
    SELECT new_price
    FROM price_history
    WHERE product_id = products.id
    ORDER BY changed_at DESC
    LIMIT 1
)
WHERE current_selling_price = 0;
```

---

## 📝 Architecture Flow Sau Khi Fix

```
Product Detail Screen
  ↓ (user saves new price)
ProductProvider.updateCurrentSellingPrice(productId, newPrice, reason)
  ↓
ProductService.updateCurrentSellingPrice(productId, newPrice, reason)
  ↓
Supabase RPC: update_product_selling_price(p_product_id, p_new_price, p_reason)
  ↓
Database Function:
  1. Get user_id from auth.uid()
  2. Get user's store_id from user_profiles
  3. Insert into price_history (product_id, new_price, old_price, changed_by, reason, store_id)
  4. Update products SET current_selling_price = p_new_price
  ↓
ProductProvider updates local cache:
  - _products[index].currentSellingPrice = newPrice
  - _currentPrices[productId] = newPrice
  - notifyListeners()
  ↓
POS Screen auto-refreshes via Provider:
  - Displays updated price correctly
  - Cart uses correct price
```

---

## ✅ Success Criteria

Migration được coi là thành công khi:

1. ✅ **Function Signature:** `update_product_selling_price` có đúng 3 params (product_id, new_price, reason)
2. ✅ **Price Sync:** Tất cả products có price_history đều có `current_selling_price > 0`
3. ✅ **Views Working:** `expiring_batches` và `low_stock_products` trả về data đúng
4. ✅ **UI Flow:** Update giá từ Product Detail → POS hiển thị giá mới ngay lập tức
5. ✅ **History Tracking:** Mọi thay đổi giá đều được ghi vào `price_history`
6. ✅ **No Errors:** Flutter app chạy không có PostgrestException

---

## 🎯 Next Steps

Nếu migration thành công:
1. Test toàn bộ checklist ở trên
2. Monitor logs để đảm bảo không có price sync errors
3. Verify PO flow vẫn hoạt động đúng
4. Deploy to staging/production

Nếu có vấn đề:
1. Check Supabase logs để xem error message
2. Verify function signature trong database
3. Run verification queries ở Bước 2
4. Liên hệ team để debug
