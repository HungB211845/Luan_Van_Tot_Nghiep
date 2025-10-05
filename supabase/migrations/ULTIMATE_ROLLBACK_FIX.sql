-- =============================================================================
-- ULTIMATE COMBINED ROLLBACK - Fix Everything
-- Date: 2025-10-05
-- Purpose: Rollback PO sync + Fix all view/function issues + Restore stable state
-- =============================================================================

BEGIN;

-- =============================================================================
-- PART 1: ROLLBACK PO SYNC ENHANCEMENT
-- =============================================================================

DO $$ BEGIN
    RAISE NOTICE '=== PART 1: Rolling back PO Sync Enhancement ===';
END $$;

-- Drop PO inventory impact view
DROP VIEW IF EXISTS po_inventory_impact CASCADE;

-- Drop enhanced RPC functions
DROP FUNCTION IF EXISTS create_batches_from_po(UUID);
DROP FUNCTION IF EXISTS get_po_price_analysis(UUID);

-- Restore original simple create_batches_from_po function
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
RETURNS INTEGER AS $$
DECLARE
  po_record RECORD;
  item_record RECORD;
  batch_count INTEGER := 0;
  new_batch_number TEXT;
  user_store_id UUID;
BEGIN
  -- Get current user's store_id for security
  SELECT store_id INTO user_store_id
  FROM user_profiles
  WHERE id = auth.uid();

  IF user_store_id IS NULL THEN
    RAISE EXCEPTION 'User not associated with any store';
  END IF;

  -- Get PO info
  SELECT po.*, c.name as supplier_name
  INTO po_record
  FROM purchase_orders po
  LEFT JOIN companies c ON po.supplier_id = c.id
  WHERE po.id = po_id
  AND po.store_id = user_store_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase Order not found or access denied: %', po_id;
  END IF;

  IF po_record.status != 'DELIVERED' THEN
    RAISE EXCEPTION 'PO must be DELIVERED status, current: %', po_record.status;
  END IF;

  -- Create batches (original logic)
  FOR item_record IN
    SELECT poi.*, p.name as product_name, p.sku as product_sku
    FROM purchase_order_items poi
    INNER JOIN products p ON poi.product_id = p.id
    WHERE poi.purchase_order_id = po_id
    AND poi.quantity > 0
    AND p.store_id = user_store_id
    ORDER BY poi.created_at
  LOOP
    new_batch_number := COALESCE(po_record.po_number, 'PO') || '-' ||
                       COALESCE(SUBSTRING(item_record.product_sku FROM 1 FOR 6), 'PROD') || '-' ||
                       LPAD(batch_count + 1::TEXT, 2, '0');

    INSERT INTO product_batches (
      product_id, batch_number, quantity, cost_price,
      received_date, purchase_order_id, supplier_id, store_id,
      notes, is_available, is_deleted
    ) VALUES (
      item_record.product_id, new_batch_number, item_record.quantity,
      item_record.unit_cost, COALESCE(po_record.delivery_date::date, CURRENT_DATE),
      po_id, po_record.supplier_id, user_store_id,
      'Auto-created from PO: ' || COALESCE(po_record.po_number, po_id::text),
      true, false
    );

    batch_count := batch_count + 1;
  END LOOP;

  RETURN batch_count;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error creating batches: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION create_batches_from_po(UUID) TO authenticated;

-- Remove PO sync columns
ALTER TABLE purchase_order_items DROP COLUMN IF EXISTS selling_price;
ALTER TABLE purchase_order_items DROP COLUMN IF EXISTS profit_margin;
ALTER TABLE purchase_order_items DROP COLUMN IF EXISTS price_updated_at;

-- Drop PO sync indexes
DROP INDEX IF EXISTS idx_purchase_order_items_selling_price;
DROP INDEX IF EXISTS idx_purchase_order_items_profit_margin;
DROP INDEX IF EXISTS idx_purchase_order_items_price_updated;

DO $$ BEGIN
    RAISE NOTICE '✅ PO Sync rollback completed';
END $$;

-- =============================================================================
-- PART 2: FIX VIEW ISSUES
-- =============================================================================

DO $$ BEGIN
    RAISE NOTICE '=== PART 2: Fixing View Issues ===';
END $$;

-- Drop ALL broken views (CASCADE will drop dependent views)
DROP VIEW IF EXISTS public.low_stock_products CASCADE;
DROP VIEW IF EXISTS public.expiring_batches CASCADE;
DROP VIEW IF EXISTS public.products_with_details CASCADE;

-- Recreate products_with_details
CREATE VIEW public.products_with_details AS
SELECT
    p.id,
    p.store_id,
    p.name,
    p.sku,
    p.category,
    p.current_selling_price,
    COALESCE((
        SELECT SUM(pb.quantity)
        FROM public.product_batches pb
        WHERE pb.product_id = p.id
          AND pb.store_id = p.store_id
          AND pb.is_available = true
    ), 0) AS available_stock,
    p.min_stock_level,
    p.is_active,
    p.created_at,
    p.updated_at
FROM public.products p
WHERE p.is_active = true;

GRANT SELECT ON public.products_with_details TO authenticated;

-- Recreate low_stock_products with CORRECT dependencies
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

-- Recreate expiring_batches
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

DO $$ BEGIN
    RAISE NOTICE '✅ Views recreated successfully';
END $$;

-- =============================================================================
-- PART 3: FIX PRICE UPDATE FUNCTION
-- =============================================================================

DO $$ BEGIN
    RAISE NOTICE '=== PART 3: Fixing Price Update Function ===';
END $$;

-- Drop all variations
DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, uuid, text);
DROP FUNCTION IF EXISTS public.update_product_selling_price(uuid, numeric, text);
DROP FUNCTION IF EXISTS public.update_product_selling_price;

-- Recreate with CORRECT signature
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

    SELECT store_id INTO v_current_store_id
    FROM public.user_profiles
    WHERE id = v_current_user_id;

    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    SELECT current_selling_price INTO v_old_price
    FROM public.products
    WHERE id = p_product_id AND store_id = v_current_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or access denied';
    END IF;

    INSERT INTO public.price_history(
        product_id, new_price, old_price,
        changed_by, reason, store_id
    ) VALUES (
        p_product_id, p_new_price, v_old_price,
        v_current_user_id, p_reason, v_current_store_id
    );

    UPDATE public.products
    SET current_selling_price = p_new_price, updated_at = NOW()
    WHERE id = p_product_id AND store_id = v_current_store_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_product_selling_price(uuid, numeric, text) TO authenticated;

DO $$ BEGIN
    RAISE NOTICE '✅ Price update function fixed';
END $$;

-- =============================================================================
-- PART 4: CLEANUP DEBUG INDEXES
-- =============================================================================

DO $$ BEGIN
    RAISE NOTICE '=== PART 4: Cleaning up debug indexes ===';
END $$;

DROP INDEX IF EXISTS public.idx_price_history_product_store;
DROP INDEX IF EXISTS public.idx_product_batches_stock_calc;
DROP INDEX IF EXISTS public.idx_products_id_store;
DROP INDEX IF EXISTS public.idx_products_zero_price;
DROP INDEX IF EXISTS public.idx_product_batches_stock_check;

-- Recreate essential indexes only
CREATE INDEX IF NOT EXISTS idx_price_history_product_changed
ON public.price_history(product_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_product_batches_available
ON public.product_batches(product_id, is_available)
WHERE is_available = true;

DO $$ BEGIN
    RAISE NOTICE '✅ Indexes cleaned up';
END $$;

-- =============================================================================
-- PART 5: RELOAD SCHEMA CACHE
-- =============================================================================

NOTIFY pgrst, 'reload schema';
NOTIFY pgrst, 'reload config';

DO $$ BEGIN
    RAISE NOTICE '✅ Schema cache reloaded';
END $$;

-- =============================================================================
-- PART 6: VERIFICATION
-- =============================================================================

DO $$ BEGIN
    RAISE NOTICE '=== PART 6: Verifying rollback ===';
END $$;

DO $$
DECLARE
    v_low_stock_exists boolean;
    v_expiring_exists boolean;
    v_pwd_exists boolean;
    v_function_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'low_stock_products'
    ) INTO v_low_stock_exists;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'expiring_batches'
    ) INTO v_expiring_exists;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_name = 'products_with_details'
    ) INTO v_pwd_exists;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_name = 'update_product_selling_price'
    ) INTO v_function_exists;

    IF v_low_stock_exists AND v_expiring_exists AND v_pwd_exists AND v_function_exists THEN
        RAISE NOTICE '✅✅✅ ALL SYSTEMS RESTORED SUCCESSFULLY ✅✅✅';
    ELSE
        RAISE WARNING 'Some objects missing - check logs';
    END IF;
END $$;

COMMIT;

-- =============================================================================
-- SUCCESS SUMMARY
-- =============================================================================

SELECT
    '🎉 ULTIMATE ROLLBACK COMPLETED 🎉' as status,
    'PO Sync rolled back + Views fixed + Function restored' as actions,
    'Database restored to stable state' as result;
