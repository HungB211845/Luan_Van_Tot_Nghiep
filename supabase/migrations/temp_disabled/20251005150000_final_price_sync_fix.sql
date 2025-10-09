-- =============================================================================
-- MIGRATION: Final Price Sync Fix - Correct Function Signature & Complete Sync
-- Date: 2025-10-05 15:00:00
-- Author: AgriPOS Development Team
-- Purpose: Fix price sync flow from Product Detail Screen to POS Screen
--          - Remove function signature conflict (no p_user_id parameter)
--          - Recreate views with correct schema
--          - Add performance indexes
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: DROP CONFLICTING TRIGGER (if exists from old migrations)
-- =============================================================================
DROP TRIGGER IF EXISTS trigger_sync_current_selling_price ON public.price_history;

-- =============================================================================
-- STEP 2: RECREATE update_product_selling_price WITH CORRECT SIGNATURE
-- This function matches the client code in ProductService.dart
-- =============================================================================

-- Drop all variations of the function
DROP FUNCTION IF EXISTS update_product_selling_price(uuid, numeric, uuid, text);
DROP FUNCTION IF EXISTS update_product_selling_price(uuid, numeric, text);
DROP FUNCTION IF EXISTS update_product_selling_price(uuid, numeric);
DROP FUNCTION IF EXISTS update_product_selling_price;

-- Create function with correct 3-parameter signature (no p_user_id)
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
BEGIN
    -- Get current user's ID from auth context
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

    -- Get the old price from products table for history tracking
    SELECT current_selling_price INTO v_old_price
    FROM public.products
    WHERE id = p_product_id
      AND store_id = v_current_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or access denied';
    END IF;

    -- Insert price history entry FIRST (for audit trail)
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

    -- Then update the current selling price in products table
    UPDATE public.products
    SET
        current_selling_price = p_new_price,
        updated_at = NOW()
    WHERE id = p_product_id
      AND store_id = v_current_store_id;

END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION update_product_selling_price(uuid, numeric, text) TO authenticated;

-- =============================================================================
-- STEP 3: RECREATE VIEWS WITH CORRECT SCHEMA
-- =============================================================================

-- 3.1. Fix expiring_batches view
DROP VIEW IF EXISTS public.expiring_batches;
CREATE OR REPLACE VIEW public.expiring_batches AS
SELECT
    pb.id,
    pb.product_id,
    pb.store_id,
    pb.batch_number,
    pb.quantity,
    pb.expiry_date,
    p.name AS product_name,
    p.sku,
    (pb.expiry_date - CURRENT_DATE) AS days_until_expiry
FROM
    public.product_batches pb
JOIN
    public.products p ON pb.product_id = p.id AND pb.store_id = p.store_id
WHERE
    pb.expiry_date IS NOT NULL
    AND pb.expiry_date > CURRENT_DATE
    AND pb.is_available = true
    AND pb.quantity > 0;

-- 3.2. Fix low_stock_products view
DROP VIEW IF EXISTS public.low_stock_products;
CREATE OR REPLACE VIEW public.low_stock_products AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    p_with_details.available_stock AS current_stock,
    c.name AS company_name,
    p.is_active
FROM
    public.products p
JOIN
    public.products_with_details p_with_details ON p.id = p_with_details.id
LEFT JOIN
    public.companies c ON p.company_id = c.id AND p.store_id = c.store_id
WHERE
    p.is_active = true
    AND p_with_details.available_stock <= p.min_stock_level;

-- Grant view permissions
GRANT SELECT ON public.expiring_batches TO authenticated;
GRANT SELECT ON public.low_stock_products TO authenticated;

-- =============================================================================
-- STEP 4: CREATE PERFORMANCE INDEXES
-- =============================================================================

-- Index for price_history lookups by product and store
CREATE INDEX IF NOT EXISTS idx_price_history_product_store
ON public.price_history(product_id, store_id, changed_at DESC);

-- Composite index on product_batches for stock calculations
CREATE INDEX IF NOT EXISTS idx_product_batches_stock_check
ON public.product_batches(product_id, store_id, is_available, quantity, expiry_date);

-- Index on products for price updates
CREATE INDEX IF NOT EXISTS idx_products_id_store
ON public.products(id, store_id);

-- Index for products with zero price (used in sync queries)
CREATE INDEX IF NOT EXISTS idx_products_zero_price
ON public.products(id, store_id)
WHERE current_selling_price = 0 OR current_selling_price IS NULL;

-- =============================================================================
-- STEP 5: VERIFICATION CHECKS
-- =============================================================================

DO $$
BEGIN
    -- Verify function exists with correct signature
    PERFORM 1
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'update_product_selling_price'
      AND pg_get_function_arguments(p.oid) = 'p_product_id uuid, p_new_price numeric, p_reason text DEFAULT ''Manual price update''::text';

    IF FOUND THEN
        RAISE NOTICE '✅ update_product_selling_price function created with correct signature';
    ELSE
        RAISE WARNING '⚠️ Function signature verification failed';
    END IF;

    -- Verify views exist
    PERFORM 1 FROM information_schema.views WHERE table_name = 'expiring_batches';
    IF FOUND THEN
        RAISE NOTICE '✅ expiring_batches view created';
    END IF;

    PERFORM 1 FROM information_schema.views WHERE table_name = 'low_stock_products';
    IF FOUND THEN
        RAISE NOTICE '✅ low_stock_products view created';
    END IF;

    -- Verify indexes exist
    PERFORM 1 FROM pg_indexes WHERE indexname = 'idx_price_history_product_store';
    IF FOUND THEN
        RAISE NOTICE '✅ Price history index created';
    END IF;

END $$;

-- =============================================================================
-- SUMMARY OUTPUT
-- =============================================================================

SELECT
    '✅ Final Price Sync Fix Completed' as status,
    'Function signature: update_product_selling_price(product_id, new_price, reason)' as step1,
    'Views recreated: expiring_batches, low_stock_products' as step2,
    'Performance indexes added' as step3,
    'Ready for price sync from history' as step4;

COMMIT;
