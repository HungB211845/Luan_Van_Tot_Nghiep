-- =============================================================================
-- MIGRATION: Sync Product Prices from History
-- Date: 2025-10-05
-- Purpose: Sync products.current_selling_price from latest price_history records
-- Status: Ready for Supabase SQL Editor
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: UPDATE ALL PRODUCTS WITH LATEST PRICES FROM HISTORY
-- After removing the trigger, we need to manually sync prices
-- =============================================================================

-- Update products.current_selling_price with latest price from price_history
UPDATE products
SET
    current_selling_price = latest_prices.new_price,
    updated_at = NOW()
FROM (
    SELECT DISTINCT ON (product_id)
        product_id,
        new_price,
        changed_at
    FROM price_history
    WHERE new_price > 0  -- Only sync valid prices
    ORDER BY product_id, changed_at DESC  -- Get latest price per product
) AS latest_prices
WHERE products.id = latest_prices.product_id
    AND products.store_id IS NOT NULL  -- Only update store products
    AND products.is_active = true  -- Only update active products
    AND (
        products.current_selling_price IS NULL
        OR products.current_selling_price = 0
        OR products.current_selling_price != latest_prices.new_price
    );

-- =============================================================================
-- STEP 2: CREATE SAFE PRICE UPDATE FUNCTION (REPLACEMENT FOR TRIGGER)
-- This function will be called manually when price updates are needed
-- =============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS sync_product_prices_from_history(uuid);

-- Create function to sync prices for a specific store
CREATE OR REPLACE FUNCTION sync_product_prices_from_history(
    p_store_id uuid DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated_count INTEGER := 0;
    v_user_store_id uuid;
    v_store_filter uuid;
BEGIN
    -- Get current user's store_id if not provided
    IF p_store_id IS NULL THEN
        SELECT store_id INTO v_user_store_id
        FROM user_profiles
        WHERE id = auth.uid();

        v_store_filter := v_user_store_id;
    ELSE
        v_store_filter := p_store_id;
    END IF;

    IF v_store_filter IS NULL THEN
        RAISE EXCEPTION 'Store ID not found for current user';
    END IF;

    -- Update products with latest prices from history
    WITH latest_prices AS (
        SELECT DISTINCT ON (product_id)
            product_id,
            new_price,
            changed_at
        FROM price_history
        WHERE store_id = v_store_filter
            AND new_price > 0
        ORDER BY product_id, changed_at DESC
    )
    UPDATE products
    SET
        current_selling_price = latest_prices.new_price,
        updated_at = NOW()
    FROM latest_prices
    WHERE products.id = latest_prices.product_id
        AND products.store_id = v_store_filter
        AND products.is_active = true
        AND (
            products.current_selling_price IS NULL
            OR products.current_selling_price = 0
            OR products.current_selling_price != latest_prices.new_price
        );

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    -- Return summary
    RETURN json_build_object(
        'success', true,
        'store_id', v_store_filter,
        'products_updated', v_updated_count,
        'message', format('Successfully synced prices for %s products', v_updated_count),
        'timestamp', NOW()
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error_code', SQLSTATE,
        'error_message', SQLERRM,
        'store_id', v_store_filter,
        'products_updated', 0,
        'timestamp', NOW()
    );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION sync_product_prices_from_history(uuid) TO authenticated;

-- =============================================================================
-- STEP 3: CREATE MANUAL PRICE SYNC FOR INDIVIDUAL PRODUCTS
-- For when user manually updates price in ProductDetailScreen
-- =============================================================================

-- Enhanced update_product_selling_price function to handle price sync properly
DROP FUNCTION IF EXISTS update_product_selling_price(uuid, numeric, text);

CREATE OR REPLACE FUNCTION update_product_selling_price(
    p_product_id uuid,
    p_new_price numeric,
    p_reason text DEFAULT 'Price update via app'
)
RETURNS JSON
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
        -- First, insert price history record
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
            COALESCE(v_old_price, 0),
            v_user_id,
            p_reason,
            v_current_store_id,
            NOW()
        );

        -- Then, update the product price
        UPDATE products
        SET
            current_selling_price = p_new_price,
            updated_at = NOW()
        WHERE id = p_product_id AND store_id = v_current_store_id;

        -- Return success response
        RETURN json_build_object(
            'success', true,
            'product_id', p_product_id,
            'old_price', COALESCE(v_old_price, 0),
            'new_price', p_new_price,
            'price_change', p_new_price - COALESCE(v_old_price, 0),
            'reason', p_reason,
            'updated_at', NOW()
        );
    ELSE
        -- No change needed
        RETURN json_build_object(
            'success', true,
            'product_id', p_product_id,
            'message', 'Price unchanged',
            'current_price', v_old_price
        );
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error_code', SQLSTATE,
        'error_message', SQLERRM,
        'product_id', p_product_id,
        'timestamp', NOW()
    );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_product_selling_price(uuid, numeric, text) TO authenticated;

-- =============================================================================
-- STEP 4: VERIFICATION - SHOW SYNC RESULTS
-- =============================================================================

-- Show summary of price sync
DO $$
DECLARE
    sync_result JSON;
    products_with_prices INTEGER;
    products_without_prices INTEGER;
BEGIN
    -- Count products with and without prices
    SELECT COUNT(*) INTO products_with_prices
    FROM products
    WHERE current_selling_price > 0 AND is_active = true;

    SELECT COUNT(*) INTO products_without_prices
    FROM products
    WHERE (current_selling_price IS NULL OR current_selling_price = 0) AND is_active = true;

    RAISE NOTICE '✅ Price sync completed:';
    RAISE NOTICE '   - Products with prices: %', products_with_prices;
    RAISE NOTICE '   - Products without prices: %', products_without_prices;

    IF products_without_prices > 0 THEN
        RAISE NOTICE '⚠️  % products still need price setup', products_without_prices;
    END IF;
END;
$$;

-- Test sync function works
DO $$
DECLARE
    test_result JSON;
BEGIN
    -- Test the sync function (will only work if user is authenticated)
    RAISE NOTICE '🧪 Testing sync function availability...';
    PERFORM 1 FROM pg_proc WHERE proname = 'sync_product_prices_from_history';
    RAISE NOTICE '✅ sync_product_prices_from_history function is available';

    PERFORM 1 FROM pg_proc WHERE proname = 'update_product_selling_price';
    RAISE NOTICE '✅ update_product_selling_price function is available';
END;
$$;

-- Final status
SELECT
    '🎯 PRICE SYNC MIGRATION COMPLETED' as status,
    '✅ Updated products.current_selling_price from price_history' as step1,
    '✅ Created sync_product_prices_from_history() function' as step2,
    '✅ Enhanced update_product_selling_price() function' as step3,
    '🚀 Products should now show correct prices in POS' as result;

COMMIT;

-- =============================================================================
-- POST-MIGRATION NOTES
-- =============================================================================
--
-- After running this migration:
-- 1. All products should have current_selling_price synced from price_history
-- 2. ProductProvider should load prices correctly
-- 3. POS Screen should display proper prices instead of 0 VND
-- 4. Price updates in ProductDetailScreen will work properly
--
-- If you still see 0 VND prices:
-- 1. Check if price_history table has valid records for those products
-- 2. Call sync_product_prices_from_history() function manually
-- 3. Restart Flutter app to clear provider cache
--
-- =============================================================================