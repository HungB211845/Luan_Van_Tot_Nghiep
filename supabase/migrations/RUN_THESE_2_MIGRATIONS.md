# 🚀 CHẠY 2 MIGRATIONS SAU KHI RESTART SUPABASE

## ✅ Prerequisites Done:
- ✅ Supabase project đã restart
- ✅ PostgREST schema cache đã clear
- ✅ Compile errors đã fix

---

## 📋 MIGRATION SEQUENCE - CHẠY ĐÚNG THỨ TỰ

### **MIGRATION 1: Fix Function & Views** (RUN THIS FIRST)
**File:** `20251005150000_final_price_sync_fix.sql`

**What it does:**
- Drops old function with wrong signature (4 params)
- Creates new function with correct signature (3 params matching client code)
- Recreates views `expiring_batches` and `low_stock_products` with correct schema
- Adds performance indexes

**How to run:**
1. Open Supabase SQL Editor
2. Copy **ENTIRE CONTENT** of `20251005150000_final_price_sync_fix.sql`
3. Paste into SQL Editor
4. Click **RUN**

**Expected Output:**
```
✅ update_product_selling_price function created with correct signature
✅ expiring_batches view created
✅ low_stock_products view created
✅ Price history index created

status: ✅ Final Price Sync Fix Completed
```

---

### **MIGRATION 2: Sync Prices from History** (RUN THIS SECOND)
**File:** `20251005140000_manual_price_sync_from_history.sql`

**What it does:**
- Updates ALL active products with their latest price from `price_history`
- Ensures `products.current_selling_price` matches latest price history entry

**How to run:**
1. Open Supabase SQL Editor
2. Copy **ENTIRE CONTENT** of `20251005140000_manual_price_sync_from_history.sql`
3. Paste into SQL Editor
4. Click **RUN**

**Expected Output:**
```
NOTICE: === PRICE SYNC SUMMARY ===
NOTICE: Total active products: X
NOTICE: Products synced with price history: Y
NOTICE: Products with zero price (after sync): 0
NOTICE: ✅ All products with price history have been synced successfully
```

**⚠️ If you see "Products with zero price (after sync): N" where N > 0:**
This means some products have price history but sync failed. Check logs for details.

---

## 🔍 VERIFICATION AFTER MIGRATIONS

**Run this query to verify prices synced correctly:**
```sql
SELECT
    p.id,
    p.name,
    p.current_selling_price as product_table_price,
    (
        SELECT new_price
        FROM price_history
        WHERE product_id = p.id
        ORDER BY changed_at DESC
        LIMIT 1
    ) as latest_history_price,
    CASE
        WHEN p.current_selling_price = (
            SELECT new_price
            FROM price_history
            WHERE product_id = p.id
            ORDER BY changed_at DESC
            LIMIT 1
        ) THEN '✅ SYNCED'
        ELSE '❌ MISMATCH'
    END as sync_status
FROM public.products p
WHERE p.is_active = true
  AND p.id IN (SELECT product_id FROM price_history)
ORDER BY sync_status DESC, p.name
LIMIT 20;
```

**Expected:** All rows should show `✅ SYNCED`

---

## 🚦 NEXT STEPS AFTER MIGRATIONS

### **Step 1: Full Restart Flutter App**
```bash
# In terminal where flutter run is running:
# Press 'q' to quit
# Then run:
flutter run -d <device-id>

# OR press 'R' (uppercase) for full restart
```

### **Step 2: Check Logs - Should NOT See:**
- ❌ "view not available"
- ❌ "column available_stock does not exist"
- ❌ "connection timeout 503"
- ❌ "function signature mismatch"

### **Step 3: Check Logs - Should See:**
- ✅ "Generating route for: /home" (no errors after)
- ✅ Products loading successfully
- ✅ No view errors

### **Step 4: Test POS Screen**
1. Navigate to POS Screen
2. Search for a product
3. **Expected:** Price displays correctly (e.g., "200,000 VND" NOT "0 VND")
4. Add product to cart
5. **Expected:** Price in cart matches product price

### **Step 5: Test Product Detail Screen**
1. Navigate to any product
2. **Expected:** Screen loads immediately (no infinite loading)
3. **Expected:** "Giá Bán Hiện Tại" shows correct price
4. Check "Lịch Sử Thay Đổi Giá" tab
5. **Expected:** Price history loads successfully

### **Step 6: Test Price Update Flow**
1. In Product Detail Screen, tap on current price to edit
2. Enter new price (e.g., 250000)
3. Tap "Xong" to save
4. **Expected:** Toast "Cập nhật giá bán thành công"
5. Go back to POS Screen
6. Search for same product
7. **Expected:** Price updated to 250,000 VND

---

## ✅ SUCCESS CRITERIA

After completing ALL steps:

- ✅ No view errors in Flutter logs
- ✅ No connection timeout errors
- ✅ POS Screen shows prices correctly (NOT 0 VND)
- ✅ Product Detail Screen loads immediately
- ✅ Can update price from Product Detail
- ✅ Updated price appears in POS Screen instantly

---

## 🚨 IF STILL NOT WORKING

**Problem: Still seeing view errors**
- Run `FORCE_SCHEMA_RELOAD.sql` again
- Check output - view should exist with `current_stock` column

**Problem: Prices still 0 VND**
- Verify migration 2 ran successfully
- Check verification query above
- Ensure price_history table has valid entries

**Problem: Function signature error**
- Re-run migration 1
- Verify function signature matches: `(product_id uuid, new_price numeric, reason text)`

---

## 📞 REPORT BACK

After running both migrations, send me:
1. ✅ Screenshot of migration 1 output
2. ✅ Screenshot of migration 2 output (with product counts)
3. ✅ Screenshot of verification query results
4. ✅ Flutter logs after app restart (last 30 lines)
5. ✅ Screenshot of POS Screen showing prices

Tao sẽ verify everything đã hoạt động đúng!
