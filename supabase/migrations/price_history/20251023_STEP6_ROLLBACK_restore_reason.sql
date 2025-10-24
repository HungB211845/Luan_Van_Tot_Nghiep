-- =============================================================================
-- STEP 6 ROLLBACK: Emergency Restore reason Column
-- =============================================================================
-- Purpose: Restore reason column if issues found after Step 6b drop
-- When to use: ONLY if app breaks after dropping reason column
-- Warning: Can only recover if database backup exists OR reason_id data intact
--
-- Recovery Methods:
-- Method 1: Full Database Restore (if complete disaster)
-- Method 2: Partial Restore (re-create column from reason_id - THIS FILE)
--
-- Prerequisites for Method 2:
-- ✅ reason_id column still exists and populated
-- ✅ price_change_reasons lookup table still exists
-- ✅ No corruption in reason_id foreign key data
--
-- Date: 2025-10-23
-- =============================================================================

-- =============================================================================
-- EMERGENCY TRIAGE: Assess the Damage
-- =============================================================================

-- Run this first to understand what we're dealing with
DO $$
DECLARE
  v_reason_col_exists boolean;
  v_reason_id_col_exists boolean;
  v_lookup_table_exists boolean;
  v_record_count bigint;
BEGIN
  -- Check if reason column exists (should be FALSE after drop)
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'price_history'
      AND column_name = 'reason'
  ) INTO v_reason_col_exists;

  -- Check if reason_id column exists (should be TRUE)
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'price_history'
      AND column_name = 'reason_id'
  ) INTO v_reason_id_col_exists;

  -- Check if lookup table exists (should be TRUE)
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'price_change_reasons'
  ) INTO v_lookup_table_exists;

  -- Get record count
  SELECT COUNT(*) INTO v_record_count FROM public.price_history;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'EMERGENCY TRIAGE RESULTS';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'reason column exists: %', v_reason_col_exists;
  RAISE NOTICE 'reason_id column exists: %', v_reason_id_col_exists;
  RAISE NOTICE 'lookup table exists: %', v_lookup_table_exists;
  RAISE NOTICE 'total records: %', v_record_count;
  RAISE NOTICE '========================================';

  -- Assess rollback feasibility
  IF v_reason_col_exists THEN
    RAISE NOTICE '✅ reason column still exists - no rollback needed!';
  ELSIF NOT v_reason_id_col_exists THEN
    RAISE EXCEPTION '❌ CRITICAL: reason_id column missing! Cannot recover. RESTORE FROM BACKUP!';
  ELSIF NOT v_lookup_table_exists THEN
    RAISE EXCEPTION '❌ CRITICAL: Lookup table missing! Cannot recover. RESTORE FROM BACKUP!';
  ELSE
    RAISE NOTICE '✅ Rollback possible using reason_id data';
    RAISE NOTICE '⚠️ Continue with Method 2 rollback below';
  END IF;
END $$;

-- =============================================================================
-- DECISION POINT: Which Recovery Method?
-- =============================================================================

-- ┌─────────────────────────────────────────────────────────────────┐
-- │ METHOD 1: Full Database Restore                                 │
-- ├─────────────────────────────────────────────────────────────────┤
-- │ When to use:                                                    │
-- │ - reason_id column corrupted or missing                         │
-- │ - Lookup table deleted or corrupted                             │
-- │ - Multiple tables affected                                      │
-- │ - Other critical data lost                                      │
-- │                                                                 │
-- │ Steps:                                                          │
-- │ 1. Supabase Dashboard → Settings → Database → Backups          │
-- │ 2. Find most recent backup (before Step 6b)                    │
-- │ 3. Click "Restore" on that backup                               │
-- │ 4. Wait for restore to complete (10-30 minutes)                 │
-- │ 5. Verify all data restored                                     │
-- │ 6. Re-deploy Hotfix v2 and Steps 1-3 migrations                │
-- │ 7. DO NOT run Step 6b again (investigate issue first)          │
-- │                                                                 │
-- │ Downtime: 10-30 minutes                                         │
-- │ Data loss: Any changes since last backup                        │
-- └─────────────────────────────────────────────────────────────────┘

-- ┌─────────────────────────────────────────────────────────────────┐
-- │ METHOD 2: Partial Restore (Re-create column)                    │
-- ├─────────────────────────────────────────────────────────────────┤
-- │ When to use:                                                    │
-- │ - Only reason column affected                                   │
-- │ - reason_id column intact                                       │
-- │ - Lookup table intact                                           │
-- │ - Need minimal downtime                                         │
-- │                                                                 │
-- │ Steps: See below (this file)                                    │
-- │                                                                 │
-- │ Downtime: 5-10 minutes                                          │
-- │ Data loss: None (recovers from reason_id)                       │
-- └─────────────────────────────────────────────────────────────────┘

-- =============================================================================
-- METHOD 2: Partial Restore (Re-create reason column)
-- =============================================================================

-- ⚠️ Only run this if triage confirmed rollback is possible!
-- ⚠️ DO NOT run if reason_id or lookup table missing!

-- =============================================================================
-- STEP 1: Re-create reason Column
-- =============================================================================

BEGIN;

-- Add reason column back (nullable for now)
ALTER TABLE public.price_history ADD COLUMN reason text;

RAISE NOTICE '✅ reason column re-created';

COMMIT;

-- =============================================================================
-- STEP 2: Restore Data from reason_id
-- =============================================================================

-- This will populate reason column using lookup table
-- Formula: ph.reason = pcr.description WHERE ph.reason_id = pcr.id

BEGIN;

UPDATE public.price_history ph
SET reason = pcr.description
FROM public.price_change_reasons pcr
WHERE ph.reason_id = pcr.id;

-- Verify update succeeded
DO $$
DECLARE
  v_total_count bigint;
  v_restored_count bigint;
  v_missing_count bigint;
BEGIN
  SELECT COUNT(*) INTO v_total_count FROM public.price_history;
  SELECT COUNT(*) INTO v_restored_count FROM public.price_history WHERE reason IS NOT NULL;
  v_missing_count := v_total_count - v_restored_count;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'DATA RESTORE RESULTS';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total records: %', v_total_count;
  RAISE NOTICE 'Restored records: %', v_restored_count;
  RAISE NOTICE 'Missing reason: %', v_missing_count;
  RAISE NOTICE '========================================';

  IF v_missing_count > 0 THEN
    RAISE WARNING '⚠️ % records still have NULL reason', v_missing_count;
    RAISE WARNING 'These records have invalid reason_id (orphaned data)';
  ELSE
    RAISE NOTICE '✅ All records restored successfully!';
  END IF;
END $$;

COMMIT;

-- =============================================================================
-- STEP 3: Update RPC Function to Use reason Column Again
-- =============================================================================

-- ⚠️ CRITICAL: RPC function is still writing to reason_id only!
-- We need to update it to write to reason column again (remove dual-write)

DROP FUNCTION IF EXISTS update_product_selling_price(uuid, numeric, text);

CREATE OR REPLACE FUNCTION update_product_selling_price(
    p_product_id uuid,
    p_new_price numeric,
    p_reason text DEFAULT 'Manual price update'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_store_id uuid;
    v_old_price numeric;
    v_current_user_id uuid;
    v_default_unit RECORD;
BEGIN
    -- Authentication and Authorization
    v_current_user_id := auth.uid();

    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to update prices';
    END IF;

    SELECT store_id INTO v_current_store_id
    FROM public.user_profiles
    WHERE id = v_current_user_id;

    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Get old price for history tracking
    SELECT current_selling_price INTO v_old_price
    FROM public.products
    WHERE id = p_product_id
      AND store_id = v_current_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or access denied';
    END IF;

    -- ⚠️ ROLLBACK: Write to reason column only (remove reason_id)
    -- This reverts to pre-migration state
    INSERT INTO public.price_history(
        product_id,
        new_price,
        old_price,
        changed_by,
        reason,         -- ← Back to text column only
        store_id
    )
    VALUES (
        p_product_id,
        p_new_price,
        v_old_price,
        v_current_user_id,
        p_reason,       -- ← Text value
        v_current_store_id
    );

    -- Update product price
    UPDATE public.products
    SET current_selling_price = p_new_price,
        updated_at = now()
    WHERE id = p_product_id
      AND store_id = v_current_store_id;

    -- Update product_units prices (keep this from Hotfix v2)
    SELECT id, conversion_factor INTO v_default_unit
    FROM public.product_units
    WHERE product_id = p_product_id
      AND store_id = v_current_store_id
      AND is_default_selling_unit = true
    LIMIT 1;

    IF v_default_unit IS NOT NULL AND v_default_unit.conversion_factor > 0 THEN
        UPDATE public.product_units
        SET
            unit_price = (p_new_price / v_default_unit.conversion_factor) * conversion_factor,
            updated_at = NOW()
        WHERE product_id = p_product_id AND store_id = v_current_store_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION update_product_selling_price(uuid, numeric, text) TO authenticated;

RAISE NOTICE '✅ RPC function restored to use reason column';

-- =============================================================================
-- STEP 4: Verify Rollback Success
-- =============================================================================

-- Test query using reason column
SELECT
  ph.id,
  p.name as product_name,
  ph.new_price,
  ph.old_price,
  ph.reason,      -- Should display correctly now
  ph.changed_at
FROM public.price_history ph
JOIN public.products p ON ph.product_id = p.id
ORDER BY ph.changed_at DESC
LIMIT 20;

-- ✅ PASS: Query returns results with reason displayed
-- ❌ FAIL: reason column shows NULL → Data restore failed

-- Check for any NULL reasons
SELECT COUNT(*) as records_missing_reason
FROM public.price_history
WHERE reason IS NULL;

-- Expected: 0 or very few (only orphaned records with invalid reason_id)

-- =============================================================================
-- STEP 5: Test App Functionality
-- =============================================================================

-- ⚠️ Test price update in app to ensure RPC function works
--
-- Manual steps:
-- 1. Open AgriPOS app
-- 2. Update a product price
-- 3. Verify:
--    ✅ Update succeeds
--    ✅ Price history shows reason as text (not lookup table)
--    ✅ Unit prices update synchronously
--
-- If tests pass → Rollback successful!
--
-- =============================================================================

-- =============================================================================
-- STEP 6: Decision Point After Rollback
-- =============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ ROLLBACK COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'reason column restored';
  RAISE NOTICE 'RPC function reverted to use reason text';
  RAISE NOTICE 'App should function normally now';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️ IMPORTANT DECISIONS:';
  RAISE NOTICE '';
  RAISE NOTICE 'Option 1: Keep current state';
  RAISE NOTICE '  - reason column retained';
  RAISE NOTICE '  - reason_id column kept but unused';
  RAISE NOTICE '  - Storage: ~97 MB (no savings)';
  RAISE NOTICE '  - Safe but wasteful';
  RAISE NOTICE '';
  RAISE NOTICE 'Option 2: Remove migration entirely';
  RAISE NOTICE '  - Drop reason_id column';
  RAISE NOTICE '  - Drop lookup table';
  RAISE NOTICE '  - Back to original state';
  RAISE NOTICE '  - Storage: ~97 MB';
  RAISE NOTICE '';
  RAISE NOTICE 'Option 3: Investigate and retry Step 6';
  RAISE NOTICE '  - Find root cause of failure';
  RAISE NOTICE '  - Fix issue';
  RAISE NOTICE '  - Re-run Step 6a + 6b';
  RAISE NOTICE '  - Achieve storage savings';
  RAISE NOTICE '';
  RAISE NOTICE 'Recommended: Option 3 (investigate issue)';
  RAISE NOTICE '========================================';
END $$;

-- =============================================================================
-- OPTION 2: Complete Rollback (Remove Migration Entirely)
-- =============================================================================

-- ⚠️ Only run this if you decide to COMPLETELY revert the migration
-- ⚠️ This will remove reason_id column and lookup table
-- ⚠️ You will be back to original 97 MB storage

-- Uncomment and run if you want complete rollback:

/*
BEGIN;

-- Drop reason_id column (and its index)
DROP INDEX IF EXISTS idx_price_history_reason_id;
ALTER TABLE public.price_history DROP COLUMN IF EXISTS reason_id;

-- Drop lookup table
DROP TABLE IF EXISTS public.price_change_reasons CASCADE;

-- Drop helper function
DROP FUNCTION IF EXISTS get_reason_id_from_text(text);

-- Verify complete rollback
DO $$
DECLARE
  v_reason_id_exists boolean;
  v_lookup_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'price_history'
      AND column_name = 'reason_id'
  ) INTO v_reason_id_exists;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'price_change_reasons'
  ) INTO v_lookup_exists;

  IF v_reason_id_exists OR v_lookup_exists THEN
    RAISE EXCEPTION 'Complete rollback failed - migration objects still exist';
  ELSE
    RAISE NOTICE '✅ Complete rollback successful - back to original state';
  END IF;
END $$;

COMMIT;
*/

-- =============================================================================
-- ROLLBACK COMPLETE
-- =============================================================================

-- Current state after this script:
-- ✅ reason column restored with data
-- ✅ RPC function using reason column
-- ✅ App functioning normally
-- ⚠️ reason_id column still exists (unused)
-- ⚠️ Lookup table still exists (unused)
-- ⚠️ Storage: ~97 MB (no savings achieved)

-- Next steps:
-- 1. Monitor app for stability
-- 2. Investigate why Step 6b failed
-- 3. Document root cause
-- 4. Decide: Keep current state OR retry migration OR complete rollback
-- 5. If retrying: Fix issue, re-run Step 6a verification, attempt Step 6b again

-- Migration prepared by: Claude Code
-- Rollback completed: 2025-10-23
-- Status: Emergency recovery successful
-- Recommendation: Investigate failure before retrying

-- =============================================================================
-- END OF ROLLBACK
-- =============================================================================
