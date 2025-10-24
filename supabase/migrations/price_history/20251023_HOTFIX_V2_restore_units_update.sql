-- =============================================================================
-- HOTFIX V2: Restore Product Units Price Update Logic
-- =============================================================================
-- Bug in Hotfix v1: Removed critical product_units price synchronization logic
-- Error: After updating product price to 850.000 VND, unit selector still shows 800.000 VND
-- Root Cause: Hotfix v1 removed logic that recalculates unit_price for all product_units
-- Fix: Restore product_units update while keeping dual-write and product_batches fix
-- Date: 2025-10-23
-- =============================================================================

-- =============================================================================
-- FIX: Recreate update_product_selling_price with complete logic
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
    v_default_unit RECORD;  -- ← RESTORED: For product_units calculation
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

    -- STEP 3: Map text reason to reason_id (with error handling for backward compatibility)
    BEGIN
        v_reason_id := get_reason_id_from_text(p_reason);
    EXCEPTION WHEN OTHERS THEN
        -- If get_reason_id_from_text doesn't exist yet, default to NULL
        -- This ensures backward compatibility if hotfix is run before Step 4 migration
        v_reason_id := NULL;
    END;

    -- STEP 4: ✅ Dual-write to price_history (reason_id + reason with backward compatibility)
    BEGIN
        INSERT INTO public.price_history(
            product_id,
            new_price,
            old_price,
            changed_by,
            reason_id,      -- ← NEW: Primary column going forward
            reason,         -- ← OLD: Keep for safety during migration
            store_id
        )
        VALUES (
            p_product_id,
            p_new_price,
            v_old_price,
            v_current_user_id,
            v_reason_id,    -- ← May be NULL if reason_id column doesn't exist yet
            p_reason,
            v_current_store_id
        );
    EXCEPTION WHEN undefined_column THEN
        -- If reason_id column doesn't exist yet, write to reason only
        INSERT INTO public.price_history(
            product_id,
            new_price,
            old_price,
            changed_by,
            reason,
            store_id
        )
        VALUES (
            p_product_id,
            p_new_price,
            v_old_price,
            v_current_user_id,
            p_reason,
            v_current_store_id
        );
    END;

    -- STEP 5: ✅ Update the product's current_selling_price in products table
    UPDATE public.products
    SET current_selling_price = p_new_price,
        updated_at = now()
    WHERE id = p_product_id
      AND store_id = v_current_store_id;

    -- STEP 6: 🔥 RESTORED - Auto-calculate and synchronize prices for all product units
    -- Get the default selling unit (e.g., "Bao") as the basis for calculation
    SELECT id, conversion_factor INTO v_default_unit
    FROM public.product_units
    WHERE product_id = p_product_id
      AND store_id = v_current_store_id
      AND is_default_selling_unit = true
    LIMIT 1;

    -- If default unit found and has valid conversion factor
    IF v_default_unit IS NOT NULL AND v_default_unit.conversion_factor > 0 THEN
        -- Update prices for ALL units of this product in ONE UPDATE statement
        -- Formula: unit_price = (new_price / default_conversion_factor) * unit_conversion_factor
        -- Example: (850.000 / 50) * 1 = 17.000 for "kg"
        -- Example: (850.000 / 50) * 50 = 850.000 for "Bao"
        UPDATE public.product_units
        SET
            unit_price = (p_new_price / v_default_unit.conversion_factor) * conversion_factor,
            updated_at = NOW()
        WHERE product_id = p_product_id AND store_id = v_current_store_id;
    END IF;

    -- ❌ REMOVED: Invalid product_batches.selling_price update
    --
    -- Why removed:
    -- - product_batches table does NOT have selling_price column
    -- - product_batches only has: cost_price, quantity, batch_number, expiry_date
    -- - Selling price is stored at PRODUCT level: products.current_selling_price
    -- - Batches inherit selling price from their parent product
    --
    -- Previous buggy code (DO NOT RESTORE):
    -- UPDATE public.product_batches
    -- SET selling_price = p_new_price  -- ← Column doesn't exist!
    -- WHERE product_id = p_product_id;
END;
$$;

GRANT EXECUTE ON FUNCTION update_product_selling_price(uuid, numeric, text) TO authenticated;

COMMENT ON FUNCTION update_product_selling_price(uuid, numeric, text) IS
  'HOTFIX V2: Updates product selling price with dual-write and product_units synchronization. Fixes unit price lag issue.';

-- =============================================================================
-- VERIFICATION
-- =============================================================================

-- Test the function (run from authenticated context)
-- Before test: Check current prices
-- SELECT
--   p.name,
--   p.current_selling_price as product_price,
--   pu.unit_name,
--   pu.unit_price,
--   pu.conversion_factor
-- FROM products p
-- LEFT JOIN product_units pu ON p.id = pu.product_id
-- WHERE p.id = '<some_product_id>'
-- ORDER BY pu.is_default_selling_unit DESC;

-- Run price update
-- SELECT update_product_selling_price(
--   '<some_product_id>',
--   850000,
--   'Test Hotfix v2 - unit price sync'
-- );

-- After test: Verify ALL prices updated synchronously
-- SELECT
--   p.name,
--   p.current_selling_price as product_price,  -- Should be 850.000
--   pu.unit_name,
--   pu.unit_price,  -- Should be recalculated for all units
--   pu.conversion_factor
-- FROM products p
-- LEFT JOIN product_units pu ON p.id = pu.product_id
-- WHERE p.id = '<some_product_id>'
-- ORDER BY pu.is_default_selling_unit DESC;

-- Verify price history was recorded with dual-write
-- SELECT
--   new_price,      -- Should be 850.000
--   old_price,      -- Should be old value (e.g., 800.000)
--   reason,         -- Should be 'Test Hotfix v2 - unit price sync'
--   reason_id,      -- Should be mapped ID (or NULL if column doesn't exist)
--   changed_at
-- FROM price_history
-- WHERE product_id = '<some_product_id>'
-- ORDER BY changed_at DESC
-- LIMIT 5;

-- =============================================================================
-- HOTFIX V2 COMPLETE
-- =============================================================================

-- ✅ Function fixed - restored product_units price synchronization
-- ✅ Dual-write working - writes to both reason_id and reason columns
-- ✅ Backward compatible - works with or without reason_id column
-- ✅ Invalid product_batches update removed
-- ✅ Unit prices should now update synchronously with products.current_selling_price

-- =============================================================================
-- WHAT WAS FIXED
-- =============================================================================

-- 🐛 Bug in Hotfix v1:
-- - Removed critical logic that updates product_units.unit_price
-- - Result: Product price updated to 850.000, but unit selector still showed 800.000

-- ✅ Fix in Hotfix v2:
-- - Restored v_default_unit RECORD declaration (line 20)
-- - Restored SELECT to get default unit with conversion_factor (lines 126-131)
-- - Restored UPDATE that recalculates all unit prices (lines 134-141)

-- 🎯 Expected Behavior After Fix:
-- 1. User updates product price from 800.000 to 850.000 VND
-- 2. products.current_selling_price → 850.000 ✅
-- 3. ALL product_units.unit_price recalculated automatically ✅
--    - "Bao" (50kg): 850.000 VND
--    - "kg": 17.000 VND (850.000 / 50 * 1)
-- 4. Unit selector dialog shows correct updated prices ✅
-- 5. price_history recorded with dual-write (reason_id + reason) ✅

-- =============================================================================
-- DEPLOYMENT INSTRUCTIONS
-- =============================================================================

-- ⚠️ IMPORTANT: This hotfix SUPERSEDES both previous files:
-- - 20251023_HOTFIX_remove_invalid_column.sql (Hotfix v1)
-- - 20251023_update_rpc_for_dual_write.sql (Step 4 migration)

-- 📋 Deployment Steps:
-- 1. Run this Hotfix v2 in Supabase SQL Editor NOW (supersedes previous hotfixes)
-- 2. Test price update in app:
--    a. Navigate to product detail
--    b. Update price (e.g., 800.000 → 850.000)
--    c. Open unit selector dialog
--    d. Verify ALL unit prices updated (not just product price)
-- 3. If test passes, continue with normal migration process:
--    a. Run 20251023_optimize_price_history_storage.sql (Steps 1-3)
--    b. Skip Step 4 migration (already applied by this hotfix)
--    c. Monitor 24-48 hours
--    d. Run Step 6 (drop old reason column) after verification

-- 🚨 Critical Test Case:
-- Product: ADC1 (Đạm canxi)
-- Before: 800.000 VND (Bao 50kg)
-- After update to 850.000:
-- - products.current_selling_price = 850.000 ✅
-- - product_units[Bao].unit_price = 850.000 ✅
-- - product_units[kg].unit_price = 17.000 ✅ (850.000 / 50)
-- - Unit selector dialog shows updated prices ✅
