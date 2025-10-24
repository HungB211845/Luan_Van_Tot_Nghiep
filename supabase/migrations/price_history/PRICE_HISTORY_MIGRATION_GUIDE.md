# Price History Storage Optimization - Migration Guide

## 📊 Overview

**Problem:** `price_history` table consuming 97.43 MB (69.37% of database storage) due to repeated text strings in `reason` column.

**Solution:** Replace `text reason` column with `smallint reason_id` + lookup table.

**Expected Savings:** 60-70 MB (60-80% reduction in `price_history` size)

**Migration Type:** ZERO DOWNTIME - App continues working throughout migration

---

## 🎯 Migration Phases

### Phase 1: Database Schema Changes (Steps 1-3)
- ✅ Create lookup table
- ✅ Add new column
- ✅ Migrate existing data
- ⏳ **NO APP CHANGES REQUIRED YET**

### Phase 2: Enable Dual-Write (Step 4)
- ✅ Update RPC functions
- ⏳ **NO DART CODE CHANGES REQUIRED** (RPC handles everything)

### Phase 3: Monitor & Verify (Steps 5-6)
- Monitor 24-48 hours
- Run verification queries
- Drop old column (after backup!)

---

## 📝 Execution Steps

### **STEP 1-3: Run Initial Migration** ⏱️ ~1 minute

**File:** `20251023_optimize_price_history_storage.sql`

**What it does:**
- Creates `price_change_reasons` lookup table
- Adds `reason_id` column to `price_history` (keeps old `reason` column intact)
- Migrates all existing data from `reason` → `reason_id`

**How to run:**

1. Open Supabase Dashboard → SQL Editor
2. Copy entire contents of `20251023_optimize_price_history_storage.sql`
3. Paste and click **Run**
4. Wait ~30-60 seconds for migration to complete

**Verification:**

Run this query to verify migration success:

```sql
-- Should return 0 (all records migrated)
SELECT COUNT(*) as unmigrated_records
FROM public.price_history
WHERE reason_id IS NULL;
```

Expected result: `0`

**If migration fails:**
- Check error message
- Run rollback commands from migration file
- Contact developer

---

### **STEP 4: Enable Dual-Write** ⏱️ ~30 seconds

**File:** `20251023_update_rpc_for_dual_write.sql`

**What it does:**
- Creates helper function to map text → reason_id
- Updates `update_product_selling_price()` RPC to write BOTH columns
- Ensures backward compatibility

**How to run:**

1. Open Supabase Dashboard → SQL Editor
2. Copy entire contents of `20251023_update_rpc_for_dual_write.sql`
3. Paste and click **Run**
4. Should complete in <5 seconds

**Verification:**

Test with this query:

```sql
-- Test helper function
SELECT get_reason_id_from_text('Updated from Purchase Order: PO-12345');
-- Expected: 2 (PO_UPDATE)

SELECT get_reason_id_from_text('Manual price update');
-- Expected: 1 (MANUAL_UPDATE)
```

**Important:**
- ✅ NO Dart code changes needed (RPC handles dual-write)
- ✅ App continues working normally
- ✅ New price changes will write to BOTH columns automatically

---

### **STEP 5: Test & Monitor** ⏱️ 24-48 hours

**Actions:**

1. **Create test price change in app:**
   - Go to any product
   - Update price
   - Verify it saves successfully

2. **Check dual-write is working:**

```sql
-- View recent price changes
SELECT
  ph.id,
  p.name as product_name,
  ph.old_price,
  ph.new_price,
  ph.reason as old_column,           -- ← Should have text
  ph.reason_id as new_column,        -- ← Should have number
  pcr.reason_code as mapped_reason   -- ← Should match text
FROM public.price_history ph
JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
JOIN public.products p ON ph.product_id = p.id
ORDER BY ph.changed_at DESC
LIMIT 10;
```

Expected: All 3 columns populated correctly

3. **Check distribution of reason codes:**

```sql
SELECT
  pcr.reason_code,
  pcr.description,
  COUNT(ph.id) as count,
  ROUND(COUNT(ph.id) * 100.0 / SUM(COUNT(ph.id)) OVER (), 2) as percentage
FROM public.price_history ph
JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
GROUP BY pcr.reason_code, pcr.description
ORDER BY count DESC;
```

4. **Monitor app for 24-48 hours:**
   - Check app logs for errors
   - Verify price changes work normally
   - Test from multiple users/devices

**Red flags to watch for:**
- ❌ Errors when updating prices
- ❌ `reason_id` is NULL for new records
- ❌ App crashes or slowdowns

**If any red flags appear:**
- STOP migration immediately
- Run rollback from migration files
- Investigate issue before proceeding

---

### **STEP 6: Drop Old Column** ⚠️ IRREVERSIBLE

**⚠️ CRITICAL: Only run this after:**
- ✅ Steps 1-5 completed successfully
- ✅ 24-48 hours of monitoring (no issues)
- ✅ Dual-write verified working
- ✅ **Database backup created** (Supabase Dashboard → Settings → Database → Backups)

**How to backup:**

1. Supabase Dashboard → Settings → Database
2. Scroll to "Backups" section
3. Click "Create backup"
4. Wait for backup to complete
5. Download backup file (optional, for extra safety)

**Final migration query:**

```sql
-- ⚠️ POINT OF NO RETURN - Backup first!

-- Drop old column
ALTER TABLE public.price_history DROP COLUMN reason;

-- Reclaim disk space (CRITICAL!)
VACUUM FULL public.price_history;
ANALYZE public.price_history;

-- Verify final size
SELECT
  pg_size_pretty(pg_total_relation_size('public.price_history')) as new_size,
  pg_size_pretty(pg_total_relation_size('public.price_change_reasons')) as lookup_size;
```

**Expected results:**
- `new_size`: ~30-40 MB (down from 97 MB)
- `lookup_size`: < 1 KB
- **Total savings: 60-70 MB**

**Post-drop verification:**

```sql
-- Should work without errors (using JOIN)
SELECT
  ph.id,
  p.name as product_name,
  ph.new_price,
  pcr.description as reason,
  ph.changed_at
FROM public.price_history ph
JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
JOIN public.products p ON ph.product_id = p.id
ORDER BY ph.changed_at DESC
LIMIT 20;
```

---

## 🔄 Rollback Instructions

### **If issues found BEFORE Step 6:**

```sql
-- Rollback Step 4 (restore old RPC function)
DROP FUNCTION IF EXISTS get_reason_id_from_text(text);

-- [Re-create old update_product_selling_price without dual-write]
-- (Contact developer for old function definition)

-- Rollback Step 2-3 (remove new column)
DROP INDEX IF EXISTS idx_price_history_reason_id;
ALTER TABLE public.price_history DROP COLUMN IF EXISTS reason_id;

-- Rollback Step 1 (remove lookup table)
DROP TABLE IF EXISTS public.price_change_reasons CASCADE;
```

### **If issues found AFTER Step 6** (Column dropped):

```sql
-- Re-create reason column
ALTER TABLE public.price_history ADD COLUMN reason text;

-- Restore data from reason_id
UPDATE public.price_history ph
SET reason = pcr.description
FROM public.price_change_reasons pcr
WHERE ph.reason_id = pcr.id;

-- Verify restoration
SELECT COUNT(*) FROM public.price_history WHERE reason IS NULL;
-- Expected: 0
```

---

## 📊 Monitoring Dashboard

After migration, monitor these metrics:

### Storage Usage

```sql
-- Check database size
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
```

### Price History Stats

```sql
-- Total records
SELECT COUNT(*) as total_price_changes FROM public.price_history;

-- Records by reason
SELECT
  pcr.description,
  COUNT(*) as count
FROM public.price_history ph
JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
GROUP BY pcr.description
ORDER BY count DESC;

-- Recent changes (last 24h)
SELECT COUNT(*) as last_24h_changes
FROM public.price_history
WHERE changed_at >= NOW() - INTERVAL '24 hours';
```

---

## ✅ Success Criteria

Migration considered successful when:

1. ✅ All verification queries pass
2. ✅ App functions normally for 48+ hours
3. ✅ No errors in logs
4. ✅ Storage reduced by 60-70 MB
5. ✅ New price changes write to `reason_id` correctly
6. ✅ Historical data accessible via JOIN queries

---

## 🆘 Troubleshooting

### Issue: "reason_id IS NULL for new records"

**Cause:** Dual-write not enabled or RPC function not updated

**Fix:**
```sql
-- Re-run Step 4 migration
\i 20251023_update_rpc_for_dual_write.sql
```

### Issue: "Permission denied for table price_change_reasons"

**Cause:** Missing GRANT permissions

**Fix:**
```sql
GRANT SELECT ON public.price_change_reasons TO authenticated;
GRANT SELECT ON public.price_change_reasons TO anon;
```

### Issue: "Migration too slow"

**Cause:** Large dataset (millions of records)

**Fix:**
```sql
-- Run migration in batches
UPDATE public.price_history
SET reason_id = get_reason_id_from_text(reason)
WHERE reason_id IS NULL
  AND id IN (
    SELECT id FROM public.price_history
    WHERE reason_id IS NULL
    ORDER BY changed_at DESC
    LIMIT 10000
  );
-- Repeat until COUNT(*) WHERE reason_id IS NULL = 0
```

### Issue: "VACUUM FULL taking too long"

**Cause:** Large table size

**Solution:** VACUUM FULL is blocking operation, run during low-traffic hours

**Alternative:**
```sql
-- Run regular VACUUM instead (non-blocking, slower space reclaim)
VACUUM public.price_history;
ANALYZE public.price_history;
```

---

## 📞 Support

If migration fails or unexpected issues occur:

1. **STOP immediately** - Don't proceed to next step
2. **Check logs** - Supabase Dashboard → Logs
3. **Run verification queries** - From this guide
4. **Contact developer** - Provide error messages and current step

---

## 📈 Expected Timeline

| Step | Duration | Downtime? |
|------|----------|-----------|
| Step 1-3 | 1 minute | ❌ No |
| Step 4 | 30 seconds | ❌ No |
| Step 5 | 24-48 hours | ❌ No |
| Step 6 | 5-10 minutes | ⚠️ Brief lock during VACUUM FULL |

**Total migration time:** 2-3 days (mostly monitoring)

**Total downtime:** ~0 seconds (VACUUM FULL may briefly lock table)

---

## ✨ Post-Migration Benefits

- 📉 60-70 MB storage saved (60-80% reduction)
- ⚡ Faster queries (smaller table size)
- 🔍 Better query performance (indexed `reason_id`)
- 📊 Cleaner data model (normalized design)
- 💰 More headroom in free Supabase tier

---

**🚀 Ready to begin? Start with Step 1-3!**
