-- =============================================================================
-- FORCE SCHEMA RELOAD - Run này SAU KHI chạy ONE_CLICK_FIX.sql
-- =============================================================================

-- Step 1: Force PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';

-- Step 2: Verify view exists with correct structure
DO $$
DECLARE
    view_exists boolean;
    column_exists boolean;
BEGIN
    -- Check if view exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'low_stock_products'
    ) INTO view_exists;

    IF view_exists THEN
        RAISE NOTICE '✅ View low_stock_products exists';

        -- Check if correct column exists
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'low_stock_products'
            AND column_name = 'current_stock'
        ) INTO column_exists;

        IF column_exists THEN
            RAISE NOTICE '✅ Column current_stock exists (correct!)';
        ELSE
            RAISE WARNING '❌ Column current_stock NOT found - view may be wrong';
        END IF;
    ELSE
        RAISE WARNING '❌ View low_stock_products does NOT exist';
    END IF;
END $$;

-- Step 3: Show view columns for verification
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'low_stock_products'
ORDER BY ordinal_position;
