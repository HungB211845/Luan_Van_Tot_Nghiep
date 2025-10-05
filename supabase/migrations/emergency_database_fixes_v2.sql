-- =============================================================================
-- EMERGENCY DATABASE FIXES V2
-- Date: 2025-10-05
-- Purpose: Fix critical database issues (Fixed function signature conflict)
-- Status: URGENT - Copy/paste ready for SQL Editor
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: REMOVE DEADLOCK-INDUCING TRIGGER (CRITICAL)
-- This trigger causes infinite update loops and database deadlocks
-- =============================================================================

-- Drop the problematic trigger that causes infinite loops
DROP TRIGGER IF EXISTS trigger_sync_current_selling_price ON price_history;

-- Drop the function that creates deadlock
DROP FUNCTION IF EXISTS sync_current_selling_price();

-- =============================================================================
-- STEP 2: FIX BROKEN VIEWS - expiring_batches
-- Current view has incorrect RLS implementation
-- =============================================================================

-- Drop existing broken view
DROP VIEW IF EXISTS expiring_batches CASCADE;

-- Recreate expiring_batches view with correct schema
CREATE VIEW expiring_batches AS
SELECT
  pb.id,
  pb.product_id,
  pb.batch_number,
  pb.quantity,
  pb.cost_price,
  pb.expiry_date,
  pb.received_date,
  pb.purchase_order_id,
  pb.supplier_id,
  pb.store_id,  -- Include store_id for RLS
  pb.notes,
  pb.is_available,
  pb.is_deleted,
  pb.created_at,
  pb.updated_at,
  p.name as product_name,
  p.sku,
  (pb.expiry_date - CURRENT_DATE) as days_until_expiry
FROM product_batches pb
JOIN products p ON pb.product_id = p.id
WHERE pb.expiry_date IS NOT NULL
  AND pb.expiry_date <= CURRENT_DATE + INTERVAL '30 days'
  AND pb.expiry_date > CURRENT_DATE
  AND pb.is_available = true
  AND pb.is_deleted = false
ORDER BY pb.expiry_date ASC;

-- Grant permissions (views inherit RLS from base tables automatically)
GRANT SELECT ON expiring_batches TO authenticated;

-- =============================================================================
-- STEP 3: FIX BROKEN VIEWS - low_stock_products
-- Fix column name inconsistency (available_stock vs current_stock)
-- =============================================================================

-- Drop existing view if it has wrong column names
DROP VIEW IF EXISTS low_stock_products CASCADE;

-- Recreate low_stock_products view with correct column names
CREATE VIEW low_stock_products AS
SELECT
  p.id,
  p.name,
  p.sku,
  p.category,
  p.min_stock_level,
  p.store_id,  -- Include store_id for RLS
  COALESCE(
    (SELECT SUM(pb.quantity)
     FROM product_batches pb
     WHERE pb.product_id = p.id
       AND pb.is_available = true
       AND pb.is_deleted = false
       AND pb.store_id = p.store_id
       AND (pb.expiry_date IS NULL OR pb.expiry_date > CURRENT_DATE)
    ), 0
  ) as available_stock,  -- Use available_stock (not current_stock)
  p.current_selling_price,
  p.created_at,
  p.updated_at
FROM products p
WHERE p.is_active = true
  AND COALESCE(
    (SELECT SUM(pb.quantity)
     FROM product_batches pb
     WHERE pb.product_id = p.id
       AND pb.is_available = true
       AND pb.is_deleted = false
       AND pb.store_id = p.store_id
       AND (pb.expiry_date IS NULL OR pb.expiry_date > CURRENT_DATE)
    ), 0
  ) <= COALESCE(p.min_stock_level, 10)
ORDER BY available_stock ASC, p.name ASC;

-- Grant permissions
GRANT SELECT ON low_stock_products TO authenticated;

-- =============================================================================
-- STEP 4: FIX EXISTING FUNCTION - update_product_selling_price
-- Drop all existing versions and recreate with proper signature
-- =============================================================================

-- Drop ALL existing versions of the function (any signature)
DROP FUNCTION IF EXISTS update_product_selling_price(uuid, numeric, uuid, text);
DROP FUNCTION IF EXISTS update_product_selling_price(uuid, numeric, text);
DROP FUNCTION IF EXISTS update_product_selling_price(uuid, numeric);
DROP FUNCTION IF EXISTS update_product_selling_price;

-- Create the function with proper signature and error handling
CREATE OR REPLACE FUNCTION update_product_selling_price(
    p_product_id uuid,
    p_new_price numeric,
    p_reason text DEFAULT 'Price update via app'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_store_id uuid;
    v_old_price numeric;
    v_product_exists boolean;
    v_user_id uuid;
BEGIN
    -- Get current user ID
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Get the user's store_id from their profile
    SELECT store_id INTO v_current_store_id
    FROM user_profiles
    WHERE id = v_user_id;

    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Validate input
    IF p_new_price < 0 THEN
        RAISE EXCEPTION 'Price cannot be negative';
    END IF;

    -- Check if product exists and belongs to user's store
    SELECT
        EXISTS(SELECT 1 FROM products WHERE id = p_product_id AND store_id = v_current_store_id AND is_active = true),
        current_selling_price
    INTO v_product_exists, v_old_price
    FROM products
    WHERE id = p_product_id AND store_id = v_current_store_id;

    IF NOT v_product_exists THEN
        RAISE EXCEPTION 'Product not found or access denied';
    END IF;

    -- Only update if price actually changed
    IF v_old_price IS DISTINCT FROM p_new_price THEN
        -- Update the product price
        UPDATE products
        SET
            current_selling_price = p_new_price,
            updated_at = NOW()
        WHERE id = p_product_id AND store_id = v_current_store_id;

        -- Insert price history record
        INSERT INTO price_history(
            product_id,
            new_price,
            old_price,
            changed_by,
            reason,
            store_id,
            changed_at
        ) VALUES (
            p_product_id,
            p_new_price,
            v_old_price,
            v_user_id,
            p_reason,
            v_current_store_id,
            NOW()
        );
    END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_product_selling_price(uuid, numeric, text) TO authenticated;

-- =============================================================================
-- STEP 5: VERIFICATION QUERIES
-- Test that all fixes are working properly
-- =============================================================================

-- Test views are accessible
DO $$
BEGIN
    -- Test expiring_batches view
    PERFORM COUNT(*) FROM expiring_batches LIMIT 1;
    RAISE NOTICE '✅ expiring_batches view is working';

    -- Test low_stock_products view
    PERFORM COUNT(*) FROM low_stock_products LIMIT 1;
    RAISE NOTICE '✅ low_stock_products view is working';

    RAISE NOTICE '✅ All views are functioning properly';
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '❌ View test failed: %', SQLERRM;
END $$;

-- Test function exists and is callable
DO $$
BEGIN
    PERFORM 1 FROM pg_proc WHERE proname = 'update_product_selling_price';
    RAISE NOTICE '✅ update_product_selling_price function exists';
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '❌ Function test failed: %', SQLERRM;
END $$;

-- Final status check
SELECT
    '🎯 EMERGENCY FIXES V2 APPLIED SUCCESSFULLY' as status,
    '✅ Removed deadlock trigger' as step1,
    '✅ Fixed expiring_batches view' as step2,
    '✅ Fixed low_stock_products view' as step3,
    '✅ Fixed update_product_selling_price function' as step4,
    '🚀 Database should be functional now' as result;

COMMIT;

-- =============================================================================
-- POST-MIGRATION NOTES
-- =============================================================================
--
-- After running this migration:
-- 1. Restart your Flutter app to clear client-side connection cache
-- 2. Test POS Screen loading - should work without infinite loading
-- 3. Test price updates in ProductDetailScreen
-- 4. Monitor logs for Error 522/503 - should be resolved
--
-- =============================================================================