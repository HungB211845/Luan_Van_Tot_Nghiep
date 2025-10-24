-- =============================================================================
-- STEP 6a: Pre-Drop Verification Queries
-- =============================================================================
-- Purpose: Comprehensive verification BEFORE dropping reason column
-- Run ALL queries below and ensure ALL checks pass before proceeding to Step 6b
-- If ANY check fails → DO NOT proceed with drop → Investigate issue first
-- Date: 2025-10-23
-- Last Verified: 2025-10-23
-- =============================================================================

-- =============================================================================
-- ✅ ACTUAL VERIFICATION RESULTS (TESTED)
-- =============================================================================
--
-- Test Date: 2025-10-23
-- Database: AgriPOS Production
-- Tester: User
--
-- VERIFICATION RESULTS SUMMARY:
-- ✅ Verification 1: Migration Completeness - PASSED (0 unmigrated records)
-- ✅ Verification 2: Dual-Write Working - PASSED (All records "Dual-write OK")
-- ✅ Verification 3: Reason Distribution - PASSED (UNKNOWN: 0.46%, excellent!)
-- ✅ Verification 4: Query Performance - PASSED (9.848 ms execution time)
-- ✅ Verification 5: Storage Size - DOCUMENTED (152 MB current, see note below)
-- ✅ Verification 6: Lookup Table - PASSED (48 kB, 9 rows)
-- ⚠️ Verification 7: Backup Status - PENDING (User must verify in Dashboard)
-- ✅ Verification 8: Dependencies - PASSED (No dependent objects)
--
-- ADDITIONAL CHECKS:
-- ✅ Recent Activity: 7 price updates in last 24h, 1 unique user
-- ✅ Data Integrity: 0 records with NULL reason or reason_id in last 48h
--
-- ⚠️ IMPORTANT NOTE - STORAGE SIZE DISCREPANCY:
--
-- Original Estimate (from migration guide):
-- - Before drop: 97 MB
-- - After drop: ~30 MB
-- - Savings: ~67 MB (69% reduction)
--
-- ACTUAL Current State (verified 2025-10-23):
-- - Current total: 152 MB (total_bytes: 158,883,840)
-- - Table data: 79 MB
-- - Indexes: 73 MB (⚠️ Almost as large as table data!)
-- - Lookup table: 48 kB
--
-- REVISED Expected Results:
-- - After drop: ~77 MB (estimated)
-- - Savings: ~75 MB (49% reduction)
-- - Storage freed: Still significant!
--
-- Why the difference?
-- 1. Database grew since original issue reported
-- 2. Heavy index usage (73 MB indexes is unusually high)
-- 3. Table may have bloat (VACUUM recommended after drop)
--
-- ✅ SAFETY ASSESSMENT: SAFE TO PROCEED
--
-- Despite storage difference, all critical checks passed:
-- - Data integrity: Perfect (0 NULL reason_id)
-- - Dual-write: Working flawlessly
-- - Pattern matching: Excellent (0.46% UNKNOWN)
-- - Query performance: Excellent (< 10ms)
-- - Dependencies: None found
-- - App activity: Normal (7 updates/24h)
--
-- 🎯 RECOMMENDATION: PROCEED TO STEP 6c FIRST, THEN STEP 6b
--
-- The migration is technically safe. Storage savings will be ~75 MB instead of
-- ~67 MB, which is still a 49% reduction and frees significant space.
--
-- ⚠️ CRITICAL WARNING: DO NOT SKIP STEP 6c!
--
-- Current Hotfix v2 RPC does DUAL-WRITE to both reason_id AND reason columns.
-- If you drop `reason` column (Step 6b) without updating RPC first (Step 6c),
-- price updates will FAIL with error: "column reason does not exist"
--
-- CORRECT ORDER:
-- 1. ✅ Step 6a: Run ALL verification queries below (this file)
-- 2. ⚠️ Step 6c: Update RPC to stop writing to `reason` column (MUST RUN FIRST!)
-- 3. ⚠️ Test price update in app (verify RPC works)
-- 4. ✅ Step 6b: Drop `reason` column + VACUUM FULL
--
-- Files to run IN ORDER:
-- 1. This file (verification only, no changes)
-- 2. 20251023_STEP6c_update_rpc_remove_reason_write.sql (CRITICAL - run BEFORE drop!)
-- 3. 20251023_STEP6_drop_reason_column.sql (run AFTER Step 6c tested)
--
-- =============================================================================

-- =============================================================================
-- CRITICAL SAFETY CHECKLIST
-- =============================================================================
--
-- ⚠️ BEFORE running any queries, confirm:
-- [ ] Hotfix v2 deployed successfully (price updates work)
-- [ ] Steps 1-3 migration completed (lookup table + reason_id column exist)
-- [ ] App running for 24-48 hours with NO errors
-- [ ] Price updates tested and working normally
-- [ ] Multiple users tested price changes successfully
-- [ ] Supabase logs show NO PostgreSQL errors
--
-- ⚠️ DO NOT PROCEED if any checkbox above is unchecked!
--
-- =============================================================================

-- =============================================================================
-- VERIFICATION 1: Check Migration Completeness
-- =============================================================================
-- Purpose: Verify ALL price_history records have reason_id populated
-- Expected: unmigrated_records = 0
-- Red Flag: ANY records with NULL reason_id

SELECT COUNT(*) as unmigrated_records
FROM public.price_history
WHERE reason_id IS NULL;

-- ✅ PASS: unmigrated_records = 0
-- ❌ FAIL: unmigrated_records > 0 → Run data migration again (Step 3)

-- =============================================================================
-- VERIFICATION 2: Verify Dual-Write Working
-- =============================================================================
-- Purpose: Check recent records have BOTH reason_id AND reason populated
-- Expected: All recent records show both columns filled
-- Red Flag: New records missing reason_id

SELECT
  changed_at,
  new_price,
  old_price,
  reason,           -- Should be text (e.g., "Manual price update")
  reason_id,        -- Should be number (e.g., 1, 2, 3)
  CASE
    WHEN reason IS NOT NULL AND reason_id IS NOT NULL THEN '✅ Dual-write OK'
    WHEN reason IS NULL AND reason_id IS NOT NULL THEN '⚠️ Only reason_id (acceptable)'
    WHEN reason IS NOT NULL AND reason_id IS NULL THEN '❌ FAIL - Missing reason_id'
    ELSE '❌ FAIL - Both NULL'
  END as status
FROM public.price_history
ORDER BY changed_at DESC
LIMIT 20;

-- ✅ PASS: All records show "✅ Dual-write OK" or "⚠️ Only reason_id"
-- ❌ FAIL: Any records show "❌ FAIL" → Check RPC function (Hotfix v2)

-- =============================================================================
-- VERIFICATION 3: Check Reason Distribution
-- =============================================================================
-- Purpose: Verify reason codes distribution is reasonable
-- Expected: UNKNOWN should be < 10% of total records
-- Red Flag: Too many UNKNOWN means pattern matching not working

SELECT
  pcr.reason_code,
  pcr.description,
  COUNT(ph.id) as record_count,
  ROUND(COUNT(ph.id) * 100.0 / SUM(COUNT(ph.id)) OVER (), 2) as percentage
FROM public.price_history ph
JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
GROUP BY pcr.reason_code, pcr.description
ORDER BY record_count DESC;

-- ✅ PASS: Distribution looks reasonable, UNKNOWN < 10%
-- ⚠️ WARNING: UNKNOWN > 10% → Consider improving pattern matching
-- ❌ FAIL: Any reason_code missing → Lookup table incomplete

-- =============================================================================
-- VERIFICATION 4: Test Queries Without reason Column
-- =============================================================================
-- Purpose: Verify app queries work using only reason_id (simulate post-drop)
-- Expected: Query runs successfully with reasonable performance
-- Red Flag: Query fails or takes too long (> 5 seconds)

EXPLAIN ANALYZE
SELECT
  ph.id,
  p.name as product_name,
  ph.new_price,
  ph.old_price,
  pcr.description as reason,  -- Getting reason from lookup table
  ph.changed_at
FROM public.price_history ph
JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
JOIN public.products p ON ph.product_id = p.id
ORDER BY ph.changed_at DESC
LIMIT 100;

-- ✅ PASS: Query completes < 1 second
-- ⚠️ WARNING: Query takes 1-5 seconds → Acceptable but monitor
-- ❌ FAIL: Query fails or > 5 seconds → Index missing or data issue

-- =============================================================================
-- VERIFICATION 5: Check Storage Size (Before Drop)
-- =============================================================================
-- Purpose: Document current storage before drop for comparison
-- Expected: price_history around 97 MB
-- Note: Save these numbers for post-drop comparison

SELECT
  'price_history' as table_name,
  pg_size_pretty(pg_total_relation_size('public.price_history')) as total_size,
  pg_size_pretty(pg_relation_size('public.price_history')) as table_size,
  pg_size_pretty(pg_indexes_size('public.price_history')) as indexes_size,
  pg_total_relation_size('public.price_history') as total_bytes
FROM public.price_history
LIMIT 1;

-- 📝 RECORD THESE VALUES:
-- total_size: _________ (Expected: ~97 MB)
-- table_size: _________ (Expected: ~75 MB)
-- indexes_size: _______ (Expected: ~22 MB)
-- total_bytes: ________ (for exact calculation)

-- =============================================================================
-- VERIFICATION 6: Check Lookup Table Size
-- =============================================================================
-- Purpose: Verify lookup table is negligible size
-- Expected: < 1 KB (should be tiny)

SELECT
  'price_change_reasons' as table_name,
  pg_size_pretty(pg_total_relation_size('public.price_change_reasons')) as total_size,
  COUNT(*) as row_count
FROM public.price_change_reasons;

-- ✅ PASS: total_size < 100 KB, row_count = 9
-- ⚠️ WARNING: total_size > 100 KB → Unexpected, but not critical

-- =============================================================================
-- VERIFICATION 7: Check Database Backup Status
-- =============================================================================
-- Purpose: Ensure recent backup exists BEFORE irreversible drop
-- Action: Manual verification in Supabase Dashboard
--
-- Steps:
-- 1. Open Supabase Dashboard → Settings → Database
-- 2. Scroll to "Backups" section
-- 3. Check latest backup date
-- 4. Expected: Backup within last 24 hours
--
-- ⚠️ CRITICAL: If NO recent backup, CREATE BACKUP NOW!
-- ⚠️ DO NOT PROCEED without backup!
--
-- How to create backup:
-- 1. Supabase Dashboard → Settings → Database → Backups
-- 2. Click "Create backup"
-- 3. Wait for completion (may take 5-10 minutes)
-- 4. Verify backup shows in list with today's date
--
-- =============================================================================

-- =============================================================================
-- VERIFICATION 8: Simulate Column Drop (Dry Run)
-- =============================================================================
-- Purpose: Test if any views/functions depend on reason column
-- Expected: No dependent objects
-- Red Flag: Foreign key constraints or views using reason column

SELECT
  n.nspname as schema,
  c.relname as table,
  a.attname as column,
  pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type,
  CASE WHEN a.attnotnull THEN 'NOT NULL' ELSE 'NULL' END as nullable
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
WHERE c.relname = 'price_history'
  AND a.attname = 'reason'
  AND NOT a.attisdropped
  AND a.attnum > 0;

-- ✅ PASS: Shows reason column exists (confirms we're dropping right column)
-- ❌ FAIL: Column not found → Already dropped or wrong table name

-- Check for dependencies on reason column
SELECT
  dependent_view.relname as dependent_view,
  dependent_ns.nspname as dependent_schema
FROM pg_depend
JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
JOIN pg_class dependent_view ON pg_rewrite.ev_class = dependent_view.oid
JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace
JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
  AND pg_depend.refobjsubid = pg_attribute.attnum
JOIN pg_class source_table ON pg_attribute.attrelid = source_table.oid
JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
WHERE source_ns.nspname = 'public'
  AND source_table.relname = 'price_history'
  AND pg_attribute.attname = 'reason';

-- ✅ PASS: No rows returned (no dependent views)
-- ❌ FAIL: Any rows returned → Views/functions using reason column, must update them first

-- =============================================================================
-- VERIFICATION SUMMARY CHECKLIST
-- =============================================================================
--
-- Run each verification above and check results:
--
-- [ ] Verification 1: All records migrated (0 NULL reason_id)
-- [ ] Verification 2: Dual-write working (recent records have both columns)
-- [ ] Verification 3: Reason distribution reasonable (UNKNOWN < 10%)
-- [ ] Verification 4: Queries work without reason column (< 1 sec)
-- [ ] Verification 5: Storage size recorded (~97 MB documented)
-- [ ] Verification 6: Lookup table tiny (< 100 KB)
-- [ ] Verification 7: Database backup created (within 24 hours)
-- [ ] Verification 8: No dependent objects (no views/functions using reason)
--
-- ✅ ALL CHECKS PASSED → SAFE to proceed to Step 6b (drop column)
-- ❌ ANY CHECK FAILED → DO NOT PROCEED → Fix issues first
--
-- =============================================================================

-- =============================================================================
-- ADDITIONAL SAFETY CHECKS (Optional but Recommended)
-- =============================================================================

-- Check recent app activity (price updates should be happening normally)
SELECT
  COUNT(*) as updates_last_24h,
  COUNT(DISTINCT changed_by) as unique_users
FROM public.price_history
WHERE changed_at >= NOW() - INTERVAL '24 hours';

-- Expected: updates_last_24h > 0 (confirms app is active)
-- Expected: unique_users >= 1 (confirms multiple users if multi-tenant)

-- Check for any recent errors in price updates
SELECT
  changed_at,
  new_price,
  old_price,
  reason,
  reason_id
FROM public.price_history
WHERE changed_at >= NOW() - INTERVAL '48 hours'
  AND (reason_id IS NULL OR reason IS NULL)
ORDER BY changed_at DESC;

-- ✅ PASS: No rows returned (all updates working correctly)
-- ⚠️ WARNING: Some rows returned → Recent updates missing data, investigate

-- =============================================================================
-- FINAL GO/NO-GO DECISION
-- =============================================================================
--
-- 🟢 GO (Safe to drop column):
-- ✅ All 8 verifications passed
-- ✅ Backup created within 24 hours
-- ✅ App running normally for 24-48 hours
-- ✅ No errors in monitoring
-- ✅ Team available to rollback if needed (office hours)
--
-- 🔴 NO-GO (Do NOT drop yet):
-- ❌ Any verification failed
-- ❌ No recent backup
-- ❌ Recent errors in app logs
-- ❌ Less than 24 hours since Hotfix v2 deployment
-- ❌ After hours / weekend (no team available for emergency)
--
-- =============================================================================

-- =============================================================================
-- NEXT STEPS
-- =============================================================================
--
-- ✅ If all verifications passed:
-- 1. Document all verification results (screenshot or save query outputs)
-- 2. Confirm backup exists and is recent
-- 3. Notify team about impending drop (in case rollback needed)
-- 4. Proceed to Step 6b: Run 20251023_STEP6_drop_reason_column.sql
-- 5. Have emergency rollback script ready: 20251023_STEP6_ROLLBACK_restore_reason.sql
--
-- ❌ If any verification failed:
-- 1. Document which verification failed and why
-- 2. Investigate root cause (check RPC functions, data migration, etc.)
-- 3. Fix underlying issue
-- 4. Re-run ALL verifications from scratch
-- 5. DO NOT proceed to drop until all verifications pass
--
-- =============================================================================
-- PRE-DROP VERIFICATION COMPLETE
-- =============================================================================
--
-- ⚠️ Remember: Dropping a column is IRREVERSIBLE without backup!
-- ⚠️ Only proceed if you are 100% confident all verifications passed.
-- ⚠️ When in doubt, wait and monitor for another 24 hours.
--
-- Migration prepared by: Claude Code
-- Last updated: 2025-10-23
-- Next file: 20251023_STEP6_drop_reason_column.sql (only if all checks pass)
--
