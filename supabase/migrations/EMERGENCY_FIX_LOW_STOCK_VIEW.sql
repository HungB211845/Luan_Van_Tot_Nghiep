-- =============================================================================
-- EMERGENCY FIX - low_stock_products View
-- PROBLEM: Migration 20251005150000 still references non-existent
--          products_with_details.available_stock column
-- SOLUTION: Use direct SUM calculation instead of join with broken view
-- =============================================================================

BEGIN;

-- Drop broken view
DROP VIEW IF EXISTS public.low_stock_products CASCADE;

-- Recreate with DIRECT calculation (no dependency on products_with_details)
CREATE VIEW public.low_stock_products AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    -- FIXED: Direct calculation from product_batches
    COALESCE((
        SELECT SUM(pb.quantity)
        FROM public.product_batches pb
        WHERE pb.product_id = p.id
          AND pb.store_id = p.store_id
          AND pb.is_available = true
    ), 0) AS current_stock,  -- ← CORRECT column name
    c.name AS company_name,
    p.is_active
FROM public.products p
LEFT JOIN public.companies c ON p.company_id = c.id AND p.store_id = c.store_id
WHERE p.is_active = true
  AND COALESCE((
      SELECT SUM(pb.quantity)
      FROM public.product_batches pb
      WHERE pb.product_id = p.id
        AND pb.store_id = p.store_id
        AND pb.is_available = true
  ), 0) <= p.min_stock_level;

-- Grant permissions
GRANT SELECT ON public.low_stock_products TO authenticated;

-- Force schema reload
NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';

-- Verify view created correctly
DO $$
DECLARE
    view_exists boolean;
    column_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema = 'public'
          AND table_name = 'low_stock_products'
    ) INTO view_exists;

    IF view_exists THEN
        RAISE NOTICE '✅ View low_stock_products created successfully';

        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'low_stock_products'
              AND column_name = 'current_stock'
        ) INTO column_exists;

        IF column_exists THEN
            RAISE NOTICE '✅ Column current_stock exists (CORRECT!)';
        ELSE
            RAISE WARNING '❌ Column current_stock NOT found';
        END IF;
    ELSE
        RAISE WARNING '❌ View low_stock_products creation failed';
    END IF;
END $$;

-- Show view structure
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'low_stock_products'
ORDER BY ordinal_position;

COMMIT;

-- SUCCESS MESSAGE
SELECT '✅ EMERGENCY FIX COMPLETED - View low_stock_products fixed with direct calculation' as status;
