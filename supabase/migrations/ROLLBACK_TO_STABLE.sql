-- =============================================================================
-- COMPREHENSIVE ROLLBACK - Quay về trạng thái STABLE của nhánh main
-- Date: 2025-10-05
-- Author: Claude Code Emergency Fix
-- Purpose: Rollback ALL changes made during price sync debugging session
-- =============================================================================

BEGIN;

-- =============================================================================
-- STEP 1: DROP ALL VIEWS CREATED/MODIFIED DURING DEBUG SESSION
-- =============================================================================

DROP VIEW IF EXISTS public.low_stock_products CASCADE;
DROP VIEW IF EXISTS public.expiring_batches CASCADE;
DROP VIEW IF EXISTS public.po_inventory_impact CASCADE;

-- =============================================================================
-- STEP 2: RECREATE ORIGINAL low_stock_products VIEW
-- (From original working state before debugging)
-- =============================================================================

CREATE OR REPLACE VIEW public.low_stock_products AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    pwd.available_stock AS current_stock,
    c.name AS company_name,
    p.is_active
FROM public.products p
LEFT JOIN public.products_with_details pwd ON p.id = pwd.id AND p.store_id = pwd.store_id
LEFT JOIN public.companies c ON p.company_id = c.id AND p.store_id = c.store_id
WHERE p.is_active = true
  AND pwd.available_stock <= p.min_stock_level;

GRANT SELECT ON public.low_stock_products TO authenticated;

-- =============================================================================
-- STEP 3: RECREATE ORIGINAL expiring_batches VIEW
-- =============================================================================

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
FROM public.product_batches pb
JOIN public.products p ON pb.product_id = p.id AND pb.store_id = p.store_id
WHERE pb.expiry_date IS NOT NULL
  AND pb.expiry_date > CURRENT_DATE
  AND pb.is_available = true
  AND pb.quantity > 0;

GRANT SELECT ON public.expiring_batches TO authenticated;

-- =============================================================================
-- STEP 4: RESTORE ORIGINAL update_product_selling_price FUNCTION
-- (3-parameter version without the bugs from debug migrations)
-- =============================================================================

DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, uuid, text);
DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, text);
DROP FUNCTION IF EXISTS public.update_product_selling_price;

CREATE OR REPLACE FUNCTION public.update_product_selling_price(
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
    -- Get current user ID
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated';
    END IF;

    -- Get user's store_id
    SELECT store_id INTO v_current_store_id
    FROM public.user_profiles
    WHERE id = v_current_user_id;

    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Get old price
    SELECT current_selling_price INTO v_old_price
    FROM public.products
    WHERE id = p_product_id
      AND store_id = v_current_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or access denied';
    END IF;

    -- Insert price history entry
    INSERT INTO public.price_history(
        product_id,
        new_price,
        old_price,
        changed_by,
        reason,
        store_id
    ) VALUES (
        p_product_id,
        p_new_price,
        v_old_price,
        v_current_user_id,
        p_reason,
        v_current_store_id
    );

    -- Update product selling price
    UPDATE public.products
    SET current_selling_price = p_new_price,
        updated_at = NOW()
    WHERE id = p_product_id
      AND store_id = v_current_store_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_product_selling_price(uuid, numeric, text) TO authenticated;

-- =============================================================================
-- STEP 5: DROP DEBUG INDEXES THAT MAY HAVE BEEN CREATED
-- =============================================================================

DROP INDEX IF EXISTS public.idx_price_history_product_store;
DROP INDEX IF EXISTS public.idx_product_batches_stock_calc;
DROP INDEX IF EXISTS public.idx_products_id_store;
DROP INDEX IF EXISTS public.idx_products_zero_price;
DROP INDEX IF EXISTS public.idx_product_batches_stock_check;

-- =============================================================================
-- STEP 6: RECREATE ESSENTIAL INDEXES (from original schema)
-- =============================================================================

-- Index for price history lookups
CREATE INDEX IF NOT EXISTS idx_price_history_product_id_changed_at
ON public.price_history(product_id, changed_at DESC);

-- Index for product batches stock calculations
CREATE INDEX IF NOT EXISTS idx_product_batches_product_id_available
ON public.product_batches(product_id, is_available)
WHERE is_available = true;

-- =============================================================================
-- STEP 7: CLEANUP ANY DEBUG TABLES OR TEMPORARY STRUCTURES
-- =============================================================================

-- Drop any temporary debug views
DROP VIEW IF EXISTS public.debug_price_state CASCADE;
DROP VIEW IF EXISTS public.verification_view CASCADE;

-- =============================================================================
-- STEP 8: RELOAD SCHEMA CACHE
-- =============================================================================

NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';

-- =============================================================================
-- STEP 9: VERIFICATION
-- =============================================================================

DO $$
DECLARE
    low_stock_view_exists boolean;
    expiring_view_exists boolean;
    function_exists boolean;
BEGIN
    -- Verify low_stock_products view
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema = 'public'
          AND table_name = 'low_stock_products'
    ) INTO low_stock_view_exists;

    -- Verify expiring_batches view
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema = 'public'
          AND table_name = 'expiring_batches'
    ) INTO expiring_view_exists;

    -- Verify function exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
          AND routine_name = 'update_product_selling_price'
    ) INTO function_exists;

    IF low_stock_view_exists AND expiring_view_exists AND function_exists THEN
        RAISE NOTICE '✅ ROLLBACK SUCCESSFUL - All core objects restored';
        RAISE NOTICE '✅ low_stock_products view restored';
        RAISE NOTICE '✅ expiring_batches view restored';
        RAISE NOTICE '✅ update_product_selling_price function restored';
    ELSE
        RAISE WARNING '⚠️ ROLLBACK INCOMPLETE - Some objects may be missing';
        IF NOT low_stock_view_exists THEN
            RAISE WARNING '❌ low_stock_products view NOT created';
        END IF;
        IF NOT expiring_view_exists THEN
            RAISE WARNING '❌ expiring_batches view NOT created';
        END IF;
        IF NOT function_exists THEN
            RAISE WARNING '❌ update_product_selling_price function NOT created';
        END IF;
    END IF;
END $$;

-- Show current view columns for verification
SELECT
    'low_stock_products' as view_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'low_stock_products'
ORDER BY ordinal_position;

COMMIT;

-- =============================================================================
-- ROLLBACK COMPLETE
-- =============================================================================

SELECT
    '✅ ROLLBACK TO STABLE COMPLETED' as status,
    'Database restored to working state from main branch' as message,
    'Next: Restart Flutter app (press R) and verify' as next_step;
