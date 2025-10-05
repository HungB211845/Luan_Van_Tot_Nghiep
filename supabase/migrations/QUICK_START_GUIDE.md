# 🚨 EMERGENCY FIX - QUICK START GUIDE

## ⚠️ CURRENT PROBLEM:
- ❌ Database views bị broken (`expiring_batches`, `low_stock_products`)
- ❌ Product Detail Screen infinite loading
- ❌ POS Screen không hiển thị giá (0 VND)
- ❌ Error: "column low_stock_products.available_stock does not exist"

## ✅ SOLUTION: Run Emergency Fix Script

### **STEP 1: Open Supabase SQL Editor**
1. Go to: https://supabase.com/dashboard
2. Select your project
3. Click "SQL Editor" in sidebar
4. Click "New Query"

### **STEP 2: Run Fix Script Step-by-Step**

**QUAN TRỌNG: Chạy TỪNG STEP riêng biệt, KHÔNG paste toàn bộ file!**

Open file: `supabase/migrations/EMERGENCY_FIX_STEP_BY_STEP.sql`

#### **Execute Step 1: Drop Broken Views**
```sql
DROP VIEW IF EXISTS public.low_stock_products CASCADE;
DROP VIEW IF EXISTS public.expiring_batches CASCADE;
```
Click "RUN" → Wait for "Success: DROP VIEW"

#### **Execute Step 2: Fix Function**
Copy toàn bộ **STEP 2** từ file → Paste vào SQL Editor → RUN
Expected: "Success: CREATE FUNCTION"

#### **Execute Step 3: Recreate expiring_batches View**
Copy toàn bộ **STEP 3** từ file → Paste vào SQL Editor → RUN
Expected: "Success: CREATE VIEW"

#### **Execute Step 4: Recreate low_stock_products View**
Copy toàn bộ **STEP 4** từ file → Paste vào SQL Editor → RUN
Expected: "Success: CREATE VIEW"

#### **Execute Step 5: Add Indexes**
Copy toàn bộ **STEP 5** từ file → Paste vào SQL Editor → RUN
Expected: Multiple "CREATE INDEX" success messages

#### **Execute Step 6: Verify Everything**
Copy toàn bộ **STEP 6** từ file → Paste vào SQL Editor → RUN
Expected:
- Function signature có 3 params (product_id, new_price, reason)
- 2 views tồn tại (expiring_batches, low_stock_products)
- 4+ indexes được tạo

### **STEP 3: Hot Restart Flutter App**

Trong terminal đang chạy `flutter run`:
1. Nhấn `r` (lowercase) để hot restart
2. Hoặc nhấn `R` (uppercase) để hot reload

Expected output:
```
flutter: 🔍 ROUTER DEBUG: Generating route for: /home
✅ No more view errors
✅ No more connection timeout
```

### **STEP 4: Test Price Sync Flow**

1. **Open Product Detail Screen:**
   - Select any product
   - Should load price history successfully (no infinite loading)

2. **Update Price:**
   - Tap on current price to edit
   - Enter new price (e.g., 250,000)
   - Tap "Xong" to save
   - Expected: ✅ Toast "Cập nhật giá bán thành công"

3. **Verify POS Screen:**
   - Go to POS Screen
   - Search for the product
   - Expected: ✅ Price displays correctly (250,000 VND)

---

## 🔍 TROUBLESHOOTING

### Problem: "Still getting view errors after running script"
**Solution:** Reload schema cache
```sql
NOTIFY pgrst, 'reload schema';
```

### Problem: "Function signature still wrong"
**Solution:** Check function signature
```sql
SELECT pg_get_function_arguments(p.oid)
FROM pg_proc p
WHERE p.proname = 'update_product_selling_price';
```
Expected: `p_product_id uuid, p_new_price numeric, p_reason text`

If wrong, re-run STEP 2.

### Problem: "Database still timing out"
**Solution:** Restart Supabase project
1. Supabase Dashboard → Settings → General
2. Click "Pause project" → Wait 30s
3. Click "Resume project"
4. Re-run emergency fix script

---

## 📊 SUCCESS CHECKLIST

After completing all steps, verify:

- ✅ **Views working:** No "view not available" errors in logs
- ✅ **Function correct:** 3-parameter signature (product_id, new_price, reason)
- ✅ **Product Detail loads:** Price history displays without infinite loading
- ✅ **POS displays prices:** Products show correct prices (not 0 VND)
- ✅ **Update price works:** Can update price from Product Detail Screen
- ✅ **Price syncs to POS:** POS Screen shows updated price immediately

---

## 🚀 NEXT: Run Price Sync Migration

**SAU KHI views và function đã fix xong, chạy migration sync prices:**

File: `supabase/migrations/20251005140000_manual_price_sync_from_history.sql`

Copy toàn bộ nội dung file này vào SQL Editor → RUN

Expected output:
```
NOTICE: === PRICE SYNC SUMMARY ===
NOTICE: Total active products: X
NOTICE: Products synced with price history: Y
NOTICE: Products with zero price (after sync): 0
NOTICE: ✅ All products with price history have been synced successfully
```

---

## 💡 FILES REFERENCE

1. **Emergency Fix Script:** `supabase/migrations/EMERGENCY_FIX_STEP_BY_STEP.sql`
2. **Price Sync Migration:** `supabase/migrations/20251005140000_manual_price_sync_from_history.sql`
3. **Full Documentation:** `supabase/migrations/PRICE_SYNC_FIX_README.md`

---

## ⏱️ ESTIMATED TIME: 5-10 minutes

1. Run emergency fix steps: ~3 mins
2. Hot restart app: ~30 secs
3. Test price sync: ~2 mins
4. Run price sync migration: ~1 min
5. Final verification: ~2 mins

**Total: ~8-10 minutes to complete fix**
