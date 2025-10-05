# 🚨 FINAL FIX INSTRUCTIONS - ĐỌC KỸ!

## ⚠️ CURRENT STATUS:
- ✅ Migration `ONE_CLICK_FIX.sql` đã chạy thành công
- ❌ Schema cache CHƯA reload → App vẫn thấy view cũ
- ❌ Database có queries timeout (Error 503)
- ❌ POS Screen hiển thị 0 VND
- ❌ Product Detail infinite loading

---

## 🔧 FIX STEPS - LÀM CHÍNH XÁC THEO THỨ TỰ:

### **STEP 1: Force Schema Reload**

**File:** `FORCE_SCHEMA_RELOAD.sql`

1. Mở Supabase SQL Editor
2. Copy TOÀN BỘ file `FORCE_SCHEMA_RELOAD.sql`
3. Paste vào SQL Editor
4. Click **RUN**

**Expected Output:**
```
NOTIFY
NOTIFY
NOTICE: ✅ View low_stock_products exists
NOTICE: ✅ Column current_stock exists (correct!)
```

**Nếu thấy:**
```
❌ View low_stock_products does NOT exist
```
→ Quay lại chạy `ONE_CLICK_FIX.sql` một lần nữa

---

### **STEP 2: Check Hung Queries (Nếu vẫn timeout)**

**File:** `CHECK_HUNG_QUERIES.sql`

1. Copy TOÀN BỘ file `CHECK_HUNG_QUERIES.sql`
2. Paste vào SQL Editor
3. Click **RUN**

**Look for:**
- Queries running > 5 minutes
- Blocking locks

**If found hung queries:**
```sql
-- Replace <PID> with actual process ID from query results
SELECT pg_terminate_backend(<PID>);
```

---

### **STEP 3: Restart Supabase Project (Recommended)**

**⚠️ QUAN TRỌNG: Làm bước này để clear tất cả cache và locks**

1. Go to: https://supabase.com/dashboard
2. Select your project
3. **Settings** (left sidebar)
4. **General** tab
5. Scroll down → Click **"Restart project"**
6. Wait 2-3 minutes for restart complete

**Why restart?**
- Clear all schema cache
- Kill all hung queries
- Reset all connections
- Fresh database state

---

### **STEP 4: Re-run Migration (After Restart)**

**File:** `ONE_CLICK_FIX.sql`

1. After project restart complete
2. Copy TOÀN BỘ file `ONE_CLICK_FIX.sql`
3. Paste vào SQL Editor
4. Click **RUN**

**Expected:**
```
NOTICE: === EMERGENCY FIX COMPLETED ===
NOTICE: ✅ Function update_product_selling_price recreated
NOTICE: ✅ View expiring_batches recreated
NOTICE: ✅ View low_stock_products recreated with correct schema
```

---

### **STEP 5: Verify Schema**

**File:** `FORCE_SCHEMA_RELOAD.sql`

1. Run this again to verify
2. Check output shows:
   - ✅ View exists
   - ✅ Column `current_stock` exists

---

### **STEP 6: Full Restart Flutter App**

**In terminal where `flutter run` is running:**

1. Press `q` to quit app
2. Run: `flutter run`
3. Wait for app to rebuild

**OR:**

Press `R` (uppercase) for full restart

---

### **STEP 7: Test Everything**

1. **Check logs - Should NOT see:**
   - ❌ "view not available"
   - ❌ "column available_stock does not exist"
   - ❌ "connection timeout 503"

2. **Check logs - Should see:**
   - ✅ "Generating route for: /home" (no errors after)
   - ✅ Products loading successfully

3. **Test POS Screen:**
   - Should display product prices (NOT 0 VND)
   - Products should have stock numbers

4. **Test Product Detail Screen:**
   - Should load immediately (no infinite loading)
   - Should show price history
   - Should show inventory batches

---

## 📋 TROUBLESHOOTING:

### Problem: "Still seeing view errors after all steps"

**Solution 1: Manual View Recreation**
```sql
DROP VIEW IF EXISTS public.low_stock_products CASCADE;

CREATE VIEW public.low_stock_products AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    COALESCE((
        SELECT SUM(pb.quantity)
        FROM public.product_batches pb
        WHERE pb.product_id = p.id
          AND pb.store_id = p.store_id
          AND pb.is_available = true
    ), 0) AS current_stock,
    c.name AS company_name,
    p.is_active
FROM public.products p
LEFT JOIN public.companies c ON p.company_id = c.id
WHERE p.is_active = true;

GRANT SELECT ON public.low_stock_products TO authenticated;
NOTIFY pgrst, 'reload schema';
```

**Solution 2: Clear Browser Cache**
- Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)

**Solution 3: Check Supabase Dashboard**
- Table Editor → Views → Check if `low_stock_products` exists
- If not, manually create using SQL above

---

### Problem: "Database still timing out"

1. **Pause & Resume project:**
   - Settings → General → Pause Project
   - Wait 30 seconds
   - Resume Project

2. **Check database plan:**
   - Free tier có limitations
   - Consider upgrading if hitting limits

3. **Optimize queries:**
   - Check if indexes are created
   - Run: `SELECT * FROM pg_indexes WHERE tablename = 'products';`

---

### Problem: "Function signature still wrong"

```sql
-- Verify function
SELECT pg_get_function_arguments(p.oid) as signature
FROM pg_proc p
WHERE p.proname = 'update_product_selling_price';

-- Expected: "p_product_id uuid, p_new_price numeric, p_reason text DEFAULT 'Manual price update'::text"
```

If wrong:
1. Re-run `ONE_CLICK_FIX.sql`
2. Restart Supabase project
3. Try again

---

## ✅ SUCCESS CRITERIA:

After completing ALL steps above:

- ✅ No view errors in Flutter logs
- ✅ No connection timeout errors
- ✅ POS Screen shows prices correctly (NOT 0 VND)
- ✅ Product Detail Screen loads immediately
- ✅ Can update price from Product Detail
- ✅ Updated price appears in POS Screen

---

## 🚀 ESTIMATED TIME:

- Step 1 (Schema reload): 1 min
- Step 2 (Check queries): 1 min
- Step 3 (Restart project): 3 mins
- Step 4 (Re-run migration): 1 min
- Step 5 (Verify): 1 min
- Step 6 (Restart app): 2 mins
- Step 7 (Test): 3 mins

**Total: ~12 minutes**

---

## 📞 IF STILL NOT WORKING:

Send me:
1. Screenshot of SQL Editor after running `FORCE_SCHEMA_RELOAD.sql`
2. Screenshot of SQL Editor after running `CHECK_HUNG_QUERIES.sql`
3. Flutter logs (last 50 lines)
4. Screenshot of POS Screen showing 0 VND

Will debug further from there.
