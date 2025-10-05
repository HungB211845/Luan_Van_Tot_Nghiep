-- =============================================================================
-- ONE-CLICK EMERGENCY FIX
-- COPY TOÀN BỘ FILE NÀY VÀO SUPABASE SQL EDITOR VÀ NHẤN "RUN"
-- =============================================================================

-- Step 1: Drop broken views
DROP VIEW IF EXISTS public.low_stock_products CASCADE;
DROP VIEW IF EXISTS public.expiring_batches CASCADE;

-- Step 2: Drop and recreate function with correct signature
DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_product_selling_price CASCADE;

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
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated';
    END IF;

    SELECT store_id INTO v_current_store_id FROM public.user_profiles WHERE id = v_current_user_id;
    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    SELECT current_selling_price INTO v_old_price FROM public.products
    WHERE id = p_product_id AND store_id = v_current_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found';
    END IF;

    INSERT INTO public.price_history(product_id, new_price, old_price, changed_by, reason, store_id)
    VALUES (p_product_id, p_new_price, v_old_price, v_current_user_id, p_reason, v_current_store_id);

    UPDATE public.products
    SET current_selling_price = p_new_price, updated_at = NOW()
    WHERE id = p_product_id AND store_id = v_current_store_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_product_selling_price(uuid, numeric, text) TO authenticated;

-- Step 3: Recreate expiring_batches view
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

-- Step 4: Recreate low_stock_products view WITH CORRECT COLUMN NAME
CREATE OR REPLACE VIEW public.low_stock_products AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.min_stock_level,
    COALESCE(
        (SELECT SUM(pb.quantity)
         FROM public.product_batches pb
         WHERE pb.product_id = p.id
           AND pb.store_id = p.store_id
           AND pb.is_available = true),
        0
    ) AS current_stock,  -- FIXED: Use direct calculation instead of products_with_details
    c.name AS company_name,
    p.is_active
FROM public.products p
LEFT JOIN public.companies c ON p.company_id = c.id AND p.store_id = c.store_id
WHERE p.is_active = true
  AND COALESCE(
      (SELECT SUM(pb.quantity)
       FROM public.product_batches pb
       WHERE pb.product_id = p.id
         AND pb.store_id = p.store_id
         AND pb.is_available = true),
      0
  ) <= p.min_stock_level;

GRANT SELECT ON public.low_stock_products TO authenticated;

-- Step 5: Add essential indexes
CREATE INDEX IF NOT EXISTS idx_price_history_product_store
ON public.price_history(product_id, store_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_batches_stock_calc
ON public.product_batches(product_id, store_id, is_available, quantity);

CREATE INDEX IF NOT EXISTS idx_products_id_store
ON public.products(id, store_id);

-- Step 6: Reload schema cache
NOTIFY pgrst, 'reload schema';

-- Success message
DO $$ BEGIN
    RAISE NOTICE '=== EMERGENCY FIX COMPLETED ===';
    RAISE NOTICE '✅ Function update_product_selling_price recreated';
    RAISE NOTICE '✅ View expiring_batches recreated';
    RAISE NOTICE '✅ View low_stock_products recreated with correct schema';
    RAISE NOTICE '✅ Indexes added for performance';
    RAISE NOTICE '✅ Schema cache reloaded';
    RAISE NOTICE '';
    RAISE NOTICE 'Next: Hot restart your Flutter app (press "r" in terminal)';
END $$;
