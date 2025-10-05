-- =============================================================================
-- EMERGENCY FIX: Run These Steps ONE BY ONE in Supabase SQL Editor
-- =============================================================================
-- IMPORTANT: Copy và paste TỪNG STEP riêng biệt, KHÔNG paste toàn bộ file!
-- Sau mỗi step, check kết quả trước khi chạy step tiếp theo.
-- =============================================================================

-- =============================================================================
-- STEP 1: DROP BROKEN VIEWS (Chạy step này TRƯỚC)
-- =============================================================================

DROP VIEW IF EXISTS public.low_stock_products CASCADE;
DROP VIEW IF EXISTS public.expiring_batches CASCADE;

-- Expected: Success message "DROP VIEW"
-- =============================================================================

-- =============================================================================
-- STEP 2: FIX UPDATE_PRODUCT_SELLING_PRICE FUNCTION
-- =============================================================================

-- Drop all variations
DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric) CASCADE;
DROP FUNCTION IF EXISTS public.update_product_selling_price CASCADE;

-- Create correct function (3 params only)
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

-- Grant permission
GRANT EXECUTE ON FUNCTION public.update_product_selling_price(uuid, numeric, text) TO authenticated;

-- Expected: Success message "CREATE FUNCTION"
-- =============================================================================

-- =============================================================================
-- STEP 3: RECREATE EXPIRING_BATCHES VIEW
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
FROM
    public.product_batches pb
JOIN
    public.products p ON pb.product_id = p.id AND pb.store_id = p.store_id
WHERE
    pb.expiry_date IS NOT NULL
    AND pb.expiry_date > CURRENT_DATE
    AND pb.is_available = true
    AND pb.quantity > 0;

GRANT SELECT ON public.expiring_batches TO authenticated;

-- Expected: Success message "CREATE VIEW"
-- =============================================================================

-- =============================================================================
-- STEP 4: RECREATE LOW_STOCK_PRODUCTS VIEW (CRITICAL FIX)
-- =============================================================================

CREATE OR REPLACE VIEW public.low_stock_products AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    p_with_details.available_stock AS current_stock,  -- FIX: Correct column alias
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

GRANT SELECT ON public.low_stock_products TO authenticated;

-- Expected: Success message "CREATE VIEW"
-- =============================================================================

-- =============================================================================
-- STEP 5: ADD PERFORMANCE INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_price_history_product_store
ON public.price_history(product_id, store_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_batches_stock_check
ON public.product_batches(product_id, store_id, is_available, quantity, expiry_date);

CREATE INDEX IF NOT EXISTS idx_products_id_store
ON public.products(id, store_id);

CREATE INDEX IF NOT EXISTS idx_products_zero_price
ON public.products(id, store_id)
WHERE current_selling_price = 0 OR current_selling_price IS NULL;

-- Expected: Multiple "CREATE INDEX" messages
-- =============================================================================

-- =============================================================================
-- STEP 6: VERIFY EVERYTHING CREATED SUCCESSFULLY
-- =============================================================================

-- Check function signature
SELECT
    routine_name,
    pg_get_function_arguments(p.oid) as function_signature
FROM information_schema.routines r
JOIN pg_proc p ON r.routine_name = p.proname
WHERE routine_name = 'update_product_selling_price';

-- Expected: 1 row with signature "p_product_id uuid, p_new_price numeric, p_reason text DEFAULT 'Manual price update'::text"

-- Check views exist
SELECT table_name
FROM information_schema.views
WHERE table_name IN ('expiring_batches', 'low_stock_products');

-- Expected: 2 rows (expiring_batches, low_stock_products)

-- Check indexes created
SELECT indexname
FROM pg_indexes
WHERE indexname LIKE 'idx_price%' OR indexname LIKE 'idx_product%';

-- Expected: Multiple rows with index names

-- =============================================================================
-- SUCCESS CRITERIA:
-- ✅ Function signature: update_product_selling_price(product_id, new_price, reason)
-- ✅ Views created: expiring_batches, low_stock_products
-- ✅ Indexes added: 4+ indexes
-- ✅ No errors in any step
-- =============================================================================
