# 🔄 ROLLBACK TO STABLE - HƯỚNG DẪN

## 🎯 MỤC ĐÍCH
Quay về trạng thái STABLE của nhánh `main` trước khi bắt đầu debug price sync issues.

## ⚠️ HIỆN TRẠNG TRƯỚC KHI ROLLBACK
- ❌ Database timeout liên tục (Error 503)
- ❌ Product Detail Screen infinite loading
- ❌ POS Screen hiển thị 0 VND
- ❌ Views `low_stock_products`, `expiring_batches` bị broken
- ❌ Function `update_product_selling_price` có bugs

## ✅ SAU KHI ROLLBACK
- ✅ Database trở về stable state
- ✅ Views hoạt động đúng với schema cũ
- ✅ Function price update hoạt động
- ✅ App có thể load products và prices

---

## 📋 BƯỚC 1: CHẠY ROLLBACK MIGRATION

### **1.1. Open Supabase SQL Editor**
1. Go to: https://supabase.com/dashboard
2. Select your project
3. Click **SQL Editor** in sidebar
4. Click **New Query**

### **1.2. Run Rollback Script**
1. Open file: `supabase/migrations/ROLLBACK_TO_STABLE.sql`
2. Copy **TOÀN BỘ** nội dung file
3. Paste vào SQL Editor
4. Click **RUN**

### **1.3. Expected Output**

Should see:
```
✅ ROLLBACK SUCCESSFUL - All core objects restored
✅ low_stock_products view restored
✅ expiring_batches view restored
✅ update_product_selling_price function restored

View columns displayed:
- id
- store_id
- name
- sku
- category
- min_stock_level
- current_stock
- company_name
- is_active

status: ✅ ROLLBACK TO STABLE COMPLETED
message: Database restored to working state from main branch
next_step: Restart Flutter app (press R) and verify
```

---

## 📋 BƯỚC 2: RESTART SUPABASE PROJECT

⚠️ **QUAN TRỌNG: Clear toàn bộ cache và connections**

1. Supabase Dashboard → Settings → General
2. Scroll down → Click **"Restart project"** (NOT pause/resume)
3. Wait 3-5 minutes for complete restart
4. Project status shows "Active" again

---

## 📋 BƯỚC 3: REVERT FLUTTER CODE CHANGES

### **3.1. Revert product_service.dart**

File: `lib/features/products/services/product_service.dart`

**Line 709:** Revert về query cũ nếu cần:
```dart
// Current (after rollback migration):
.order('current_stock', ascending: true);

// Should work with restored view
```

### **3.2. Slow Query Logging**

Các changes disable `_logSlowQuery()` có thể GIỮ LẠI vì chúng GIÚP giảm database load.

**KHÔNG CẦN REVERT** unless mày muốn re-enable logging.

---

## 📋 BƯỚC 4: HOT RESTART FLUTTER APP

Trong terminal nơi `flutter run` đang chạy:

1. Press `q` to quit
2. Run lại:
   ```bash
   flutter run -d <device-id>
   ```

Hoặc press `R` (uppercase) for full restart.

---

## 📋 BƯỚC 5: VERIFICATION

### **5.1. Check Flutter Logs**

Should **NOT** see:
- ❌ "column low_stock_products.available_stock does not exist"
- ❌ "connection timeout 503"
- ❌ "Failed to log slow query"
- ❌ "view not found"

Should **ONLY** see:
- ✅ "Generating route for: /home"
- ✅ Products loading successfully
- ✅ No errors

### **5.2. Test POS Screen**

1. Navigate to POS Screen
2. Check if products load
3. Verify prices display (NOT 0 VND)

**If still showing 0 VND:**
- Products may genuinely have no price set
- Check `products.current_selling_price` in database
- Manually set prices for test products

### **5.3. Test Product Detail Screen**

1. Navigate to any product
2. Should load immediately (no infinite loading)
3. Check "Giá Bán Hiện Tại" displays
4. Check "Lịch Sử Thay Đổi Giá" tab loads

### **5.4. Test Price Update**

1. In Product Detail, tap current price
2. Enter new price (e.g., 150000)
3. Tap "Xong"
4. Expected: Toast "Cập nhật giá bán thành công"
5. Go to POS Screen
6. Search same product
7. Expected: Price updated

---

## 🔍 TROUBLESHOOTING

### Problem: "View still showing errors"

**Solution:**
```sql
-- Verify view exists with correct structure
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'low_stock_products'
ORDER BY ordinal_position;
```

Should show column `current_stock` (not `available_stock`).

---

### Problem: "Database still timing out"

**Possible causes:**
1. Supabase free tier limits exceeded
2. Hung queries still blocking

**Solution:**
```sql
-- Check for hung queries
SELECT
    pid,
    now() - query_start as duration,
    LEFT(query, 100) as query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND (now() - query_start) > interval '1 minute'
ORDER BY duration DESC;

-- If found, kill them:
SELECT pg_terminate_backend(<PID>);
```

---

### Problem: "Products_with_details view not found"

**This is NORMAL after rollback!**

The rollback assumes `products_with_details` view exists from original schema.

If it doesn't exist, create it:
```sql
CREATE OR REPLACE VIEW public.products_with_details AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.current_selling_price,
    COALESCE((
        SELECT SUM(pb.quantity)
        FROM public.product_batches pb
        WHERE pb.product_id = p.id
          AND pb.store_id = p.store_id
          AND pb.is_available = true
    ), 0) AS available_stock,
    p.min_stock_level,
    p.is_active,
    p.created_at,
    p.updated_at
FROM public.products p
WHERE p.is_active = true;

GRANT SELECT ON public.products_with_details TO authenticated;
NOTIFY pgrst, 'reload schema';
```

---

### Problem: "Function signature still wrong"

Run verification:
```sql
SELECT pg_get_function_arguments(p.oid)
FROM pg_proc p
WHERE p.proname = 'update_product_selling_price';
```

Expected: `p_product_id uuid, p_new_price numeric, p_reason text DEFAULT 'Manual price update'::text`

If wrong, re-run `ROLLBACK_TO_STABLE.sql`.

---

## ✅ SUCCESS CRITERIA

After complete rollback:

- ✅ No database timeout errors
- ✅ POS Screen loads products with prices
- ✅ Product Detail Screen loads immediately
- ✅ Can update prices successfully
- ✅ Updated prices reflect in POS
- ✅ No view or function errors

---

## 📞 IF STILL NOT WORKING

**Last resort options:**

1. **Check Supabase usage limits:**
   - Dashboard → Settings → Billing → Usage
   - Verify not hitting free tier limits

2. **Contact Supabase Support:**
   - Dashboard → Support
   - Report persistent timeout issues

3. **Consider fresh database:**
   - Export essential data
   - Create new Supabase project
   - Import data
   - Update connection strings

---

## 🎯 WHAT WAS ROLLED BACK

1. ❌ Dropped broken `low_stock_products` view (with `available_stock` column bug)
2. ❌ Dropped broken `expiring_batches` view
3. ❌ Dropped buggy `update_product_selling_price` function variations
4. ❌ Removed debug indexes
5. ✅ Recreated original working versions of all above
6. ✅ Restored to stable state from main branch

---

## ⏱️ ESTIMATED TIME

- Step 1 (Run migration): 1 min
- Step 2 (Restart Supabase): 5 mins
- Step 3 (Revert code): 0 mins (keep slow query fix)
- Step 4 (Restart app): 1 min
- Step 5 (Verification): 3 mins

**Total: ~10 minutes to complete rollback**

---

**Sau khi rollback xong, app NÊN hoạt động trở lại như trước khi bắt đầu debug session.**
