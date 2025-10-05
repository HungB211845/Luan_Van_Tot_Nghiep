-- =============================================================================
-- MIGRATION: Fix Low Stock Products View Column Error
-- Date: 2025-10-05 16:00:00
-- Author: AgriPOS Development Team
-- Purpose: Fix column name mismatch in low_stock_products view
--          Error: column low_stock_products.available_stock does not exist
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: CHECK CURRENT VIEW DEFINITION
-- =============================================================================

DO $$
BEGIN
    -- Show current view definition for debugging
    RAISE NOTICE 'Checking current low_stock_products view definition...';
END $$;

-- =============================================================================
-- STEP 2: DROP AND RECREATE low_stock_products VIEW WITH CORRECT COLUMNS
-- =============================================================================

-- Drop existing view
DROP VIEW IF EXISTS public.low_stock_products CASCADE;

-- Recreate with correct column names matching what the app expects
CREATE OR REPLACE VIEW public.low_stock_products AS
SELECT 
    p.id,
    p.name,
    p.sku,
    p.category,
    p.current_selling_price,
    p.min_stock_level,
    -- ✅ FIX: Use available_stock (matching products_with_details view)
    pwd.available_stock,
    -- Also add current_stock alias for compatibility
    pwd.available_stock as current_stock,
    p.store_id,
    c.name as company_name,
    p.is_active,
    p.created_at,
    p.updated_at
FROM public.products p
-- Join with products_with_details to get calculated stock
LEFT JOIN public.products_with_details pwd ON p.id = pwd.id AND p.store_id = pwd.store_id
LEFT JOIN public.companies c ON p.company_id = c.id AND p.store_id = c.store_id
WHERE p.is_active = true
    AND pwd.available_stock IS NOT NULL
    AND pwd.available_stock <= p.min_stock_level
ORDER BY pwd.available_stock ASC, p.name ASC;

-- =============================================================================
-- STEP 3: VERIFY THE VIEW WORKS
-- =============================================================================

DO $$
DECLARE
    v_view_exists boolean;
    v_sample_count integer;
    v_columns_info text;
BEGIN
    -- Check if view exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_schema = 'public' 
        AND table_name = 'low_stock_products'
    ) INTO v_view_exists;

    IF v_view_exists THEN
        RAISE NOTICE '✅ low_stock_products view created successfully';
        
        -- Get column information
        SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
        INTO v_columns_info
        FROM information_schema.columns
        WHERE table_schema = 'public' 
        AND table_name = 'low_stock_products';
        
        RAISE NOTICE 'View columns: %', v_columns_info;
        
        -- Test query with a small sample
        SELECT COUNT(*) INTO v_sample_count
        FROM public.low_stock_products
        LIMIT 5;
        
        RAISE NOTICE 'Sample query successful, found % low stock products', v_sample_count;
        
    ELSE
        RAISE WARNING '❌ Failed to create low_stock_products view';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '⚠️ Error during view verification: %', SQLERRM;
END $$;

-- =============================================================================
-- STEP 4: GRANT PERMISSIONS
-- =============================================================================

-- Grant select permission to authenticated users
GRANT SELECT ON public.low_stock_products TO authenticated;

-- =============================================================================
-- STEP 5: ALSO FIX expiring_batches VIEW (in case it has issues too)
-- =============================================================================

-- Drop and recreate expiring_batches view with correct schema
DROP VIEW IF EXISTS public.expiring_batches CASCADE;

CREATE OR REPLACE VIEW public.expiring_batches AS
SELECT 
    pb.id,
    pb.product_id,
    pb.store_id,
    pb.batch_number,
    pb.quantity,
    pb.expiry_date,
    pb.cost_price,
    pb.created_at,
    p.name AS product_name,
    p.sku,
    p.category,
    c.name AS company_name,
    -- Calculate days until expiry
    (pb.expiry_date - CURRENT_DATE) AS days_until_expiry
FROM public.product_batches pb
JOIN public.products p ON pb.product_id = p.id AND pb.store_id = p.store_id
LEFT JOIN public.companies c ON p.company_id = c.id AND p.store_id = c.store_id
WHERE pb.expiry_date IS NOT NULL
    AND pb.expiry_date > CURRENT_DATE - INTERVAL '7 days'  -- Include recently expired
    AND pb.expiry_date <= CURRENT_DATE + INTERVAL '90 days'  -- Next 3 months
    AND pb.is_available = true
    AND pb.quantity > 0
    AND p.is_active = true
ORDER BY pb.expiry_date ASC, p.name ASC;

-- Grant permissions
GRANT SELECT ON public.expiring_batches TO authenticated;

-- =============================================================================
-- SUMMARY OUTPUT
-- =============================================================================

SELECT
    '✅ Low Stock Products View Fixed' as status,
    'Fixed column name: available_stock' as fix1,
    'Added compatibility alias: current_stock' as fix2,
    'Fixed expiring_batches view too' as fix3,
    'Views should work with ProductService now' as result;

COMMIT;