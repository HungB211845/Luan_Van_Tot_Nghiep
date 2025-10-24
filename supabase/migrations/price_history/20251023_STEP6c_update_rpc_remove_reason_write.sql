-- =============================================================================
-- STEP 6c: Update RPC to Stop Writing to `reason` Column
-- =============================================================================
-- ⚠️ CRITICAL: This MUST be run BEFORE Step 6b (drop column)!
--
-- Problem:
-- - Current RPC (Hotfix v2) does DUAL-WRITE to both reason_id AND reason columns
-- - If we drop `reason` column first, RPC will ERROR when trying to INSERT
-- - Price updates will FAIL until RPC is fixed
--
-- Solution:
-- - Update RPC to write ONLY to reason_id column
-- - Remove `reason` from INSERT statement
-- - Keep backward compatibility (still accepts p_reason text parameter)
--
-- Prerequisites:
-- ✅ Hotfix v2 deployed (dual-write working)
-- ✅ Steps 1-3 completed (reason_id column exists, data migrated)
-- ✅ Step 6a passed (all verifications OK)
-- ✅ get_reason_id_from_text helper function exists
--
-- IMPORTANT: Run Step 6c BEFORE Step 6b!
-- Correct order: 6a (verify) → 6c (update RPC) → 6b (drop column)
--
-- Date: 2025-10-23
-- =============================================================================

-- =============================================================================
-- VERIFICATION: Check Current State
-- =============================================================================

-- Verify reason_id column exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'price_history'
      AND column_name = 'reason_id'
  ) THEN
    RAISE EXCEPTION 'reason_id column does not exist! Run Steps 1-3 first.';
  END IF;

  RAISE NOTICE '✅ reason_id column exists';
END $$;

-- Verify helper function exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'get_reason_id_from_text'
  ) THEN
    RAISE EXCEPTION 'get_reason_id_from_text function does not exist! Run Step 4 first.';
  END IF;

  RAISE NOTICE '✅ get_reason_id_from_text function exists';
END $$;

-- Verify lookup table has data
DO $$
DECLARE
  v_reason_count int;
BEGIN
  SELECT COUNT(*) INTO v_reason_count FROM public.price_change_reasons;

  IF v_reason_count = 0 THEN
    RAISE EXCEPTION 'price_change_reasons table is empty! Run Step 1 first.';
  END IF;

  RAISE NOTICE '✅ price_change_reasons has % rows', v_reason_count;
END $$;

-- =============================================================================
-- UPDATE RPC: Remove `reason` from INSERT (Write Only to reason_id)
-- =============================================================================

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
    v_reason_id smallint;
    v_default_unit RECORD;
BEGIN
    -- STEP 1: Authentication and Authorization
    v_current_user_id := auth.uid();

    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to update prices';
    END IF;

    -- Get the user's store_id from their profile
    SELECT store_id INTO v_current_store_id
    FROM public.user_profiles
    WHERE id = v_current_user_id;

    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- STEP 2: Get old price for history tracking
    SELECT current_selling_price INTO v_old_price
    FROM public.products
    WHERE id = p_product_id
      AND store_id = v_current_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or access denied';
    END IF;

    -- STEP 3: Map text reason to reason_id
    v_reason_id := get_reason_id_from_text(p_reason);

    -- STEP 4: ✅ Write ONLY to reason_id (reason column removed from INSERT)
    -- This is the CRITICAL CHANGE for Step 6c!
    INSERT INTO public.price_history(
        product_id,
        new_price,
        old_price,
        changed_by,
        reason_id,      -- ← ONLY reason_id now (no more `reason` column!)
        store_id
    )
    VALUES (
        p_product_id,
        p_new_price,
        v_old_price,
        v_current_user_id,
        v_reason_id,    -- ← Mapped from p_reason text
        v_current_store_id
    );

    -- STEP 5: Update the product's current_selling_price
    UPDATE public.products
    SET current_selling_price = p_new_price,
        updated_at = now()
    WHERE id = p_product_id
      AND store_id = v_current_store_id;

    -- STEP 6: Auto-calculate and synchronize prices for all product units
    -- (Restored from Hotfix v2 - keep this logic!)
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

    -- ❌ REMOVED: product_batches.selling_price update (column doesn't exist)
    -- ✅ REMOVED: reason column write (preparing for column drop in Step 6b)
END;
$$;

GRANT EXECUTE ON FUNCTION update_product_selling_price(uuid, numeric, text) TO authenticated;

COMMENT ON FUNCTION update_product_selling_price(uuid, numeric, text) IS
  'Step 6c: Updates product selling price. Writes ONLY to reason_id (no longer writes to reason column). Safe to drop reason column after this.';

-- =============================================================================
-- VERIFICATION: Test RPC Function
-- =============================================================================

-- Verify RPC function was created
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'update_product_selling_price'
  ) THEN
    RAISE EXCEPTION 'RPC function was not created!';
  END IF;

  RAISE NOTICE '✅ RPC function created successfully';
END $$;

-- =============================================================================
-- TESTING: Run These Queries to Verify
-- =============================================================================

-- ⚠️ IMPORTANT: These tests should be run from authenticated context
-- (e.g., using Supabase client with actual user session, not SQL Editor)

-- Test 1: Verify function accepts correct parameters
-- (This should show the function signature)
SELECT
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as parameters,
  pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname = 'update_product_selling_price';

-- Expected:
-- function_name: update_product_selling_price
-- parameters: p_product_id uuid, p_new_price numeric, p_reason text DEFAULT 'Manual price update'::text
-- return_type: void

-- Test 2: Check recent price_history inserts
-- After running this migration, new inserts should have reason_id but MAY or MAY NOT have reason
-- (depending on whether old or new RPC was used)
SELECT
  changed_at,
  new_price,
  old_price,
  reason,           -- May be NULL for new inserts (after Step 6c)
  reason_id,        -- Should ALWAYS be populated
  CASE
    WHEN reason IS NULL AND reason_id IS NOT NULL THEN '✅ New RPC (reason_id only)'
    WHEN reason IS NOT NULL AND reason_id IS NOT NULL THEN '⚠️ Old RPC (dual-write)'
    WHEN reason IS NOT NULL AND reason_id IS NULL THEN '❌ Very old RPC (reason only)'
    ELSE '❌ ERROR (both NULL)'
  END as insert_method
FROM public.price_history
ORDER BY changed_at DESC
LIMIT 20;

-- Expected after Step 6c:
-- New inserts show "✅ New RPC (reason_id only)"
-- Old inserts may show "⚠️ Old RPC (dual-write)"

-- Test 3: Verify reason can be retrieved from reason_id
SELECT
  ph.changed_at,
  ph.new_price,
  ph.reason,                    -- May be NULL for new inserts
  ph.reason_id,                 -- Should be populated
  pcr.description as reason_from_lookup  -- Can always get reason from lookup
FROM public.price_history ph
JOIN public.price_change_reasons pcr ON ph.reason_id = pcr.id
ORDER BY ph.changed_at DESC
LIMIT 10;

-- Expected:
-- reason_from_lookup should ALWAYS show the correct reason text
-- Even if ph.reason is NULL, we can get it from lookup table

-- =============================================================================
-- POST-DEPLOYMENT TESTING (User Must Do in App)
-- =============================================================================

-- After deploying Step 6c, test in app:
--
-- 1. Navigate to product detail in AgriPOS app
-- 2. Update product price (e.g., 850.000 → 900.000)
-- 3. Verify:
--    ✅ Price update succeeds (no errors)
--    ✅ Product price shows new value (900.000)
--    ✅ Unit prices update synchronously
--    ✅ Price history records the change
--
-- 4. Check database:
--    SELECT * FROM price_history ORDER BY changed_at DESC LIMIT 5;
--    Expected:
--    - New record exists
--    - reason_id populated (should be 1 for "Manual update")
--    - reason MAY be NULL (this is OK! We can get it from lookup)
--
-- 5. Verify reason displays correctly in app:
--    - App should JOIN price_history with price_change_reasons
--    - Reason should display as "Cập nhật giá thủ công" or similar
--
-- If all tests pass → Safe to proceed to Step 6b (drop column)
--
-- =============================================================================

-- =============================================================================
-- MIGRATION COMPLETE
-- =============================================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ STEP 6c COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'RPC updated: Now writes ONLY to reason_id';
  RAISE NOTICE 'Removed: reason column write';
  RAISE NOTICE 'Kept: All other logic (products update, units sync)';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️ CRITICAL NEXT STEPS:';
  RAISE NOTICE '1. Test price update in app (MUST DO!)';
  RAISE NOTICE '2. Verify new inserts have reason_id populated';
  RAISE NOTICE '3. Verify app can display reason from lookup table';
  RAISE NOTICE '4. If all tests pass, proceed to Step 6b (drop column)';
  RAISE NOTICE '';
  RAISE NOTICE '❌ DO NOT run Step 6b until app testing passes!';
  RAISE NOTICE '========================================';
END $$;

-- =============================================================================
-- COMPARISON: What Changed from Hotfix v2
-- =============================================================================

-- BEFORE (Hotfix v2):
-- INSERT INTO price_history(
--     product_id, new_price, old_price, changed_by,
--     reason_id,  -- NEW column
--     reason,     -- OLD column (dual-write)
--     store_id
-- ) VALUES (
--     p_product_id, p_new_price, v_old_price, v_current_user_id,
--     v_reason_id,
--     p_reason,   -- ← Writing to reason column
--     v_current_store_id
-- );

-- AFTER (Step 6c):
-- INSERT INTO price_history(
--     product_id, new_price, old_price, changed_by,
--     reason_id,  -- ONLY reason_id now
--     store_id
-- ) VALUES (
--     p_product_id, p_new_price, v_old_price, v_current_user_id,
--     v_reason_id,  -- ← Only reason_id (no more reason write!)
--     v_current_store_id
-- );

-- Key Change:
-- - Removed `reason` from INSERT column list
-- - Removed `p_reason` from INSERT VALUES list
-- - Function signature unchanged (still accepts p_reason parameter)
-- - p_reason is mapped to reason_id via get_reason_id_from_text
-- - After this change, safe to drop `reason` column in Step 6b

-- =============================================================================
-- ROLLBACK (if Step 6c causes issues)
-- =============================================================================

-- If Step 6c RPC causes issues, restore Hotfix v2 dual-write:
-- Run: supabase/migrations/price_history/20251023_HOTFIX_V2_restore_units_update.sql

-- =============================================================================
-- END OF STEP 6c
-- =============================================================================

-- Migration prepared by: Claude Code
-- Migration completed: 2025-10-23
-- Status: ✅ RPC updated to stop writing to reason column
-- Next step: Test in app, then run Step 6b (drop column)
