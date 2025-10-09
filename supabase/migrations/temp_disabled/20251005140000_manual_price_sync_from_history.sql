-- Migration: Manual Price Sync from History
-- Date: 2025-10-05
-- Author: Gemini
-- Purpose: One-time data backfill to synchronize products.current_selling_price with the latest valid price from price_history.
-- This is necessary after removing the old trigger-based sync mechanism.
-- UPDATED: Now syncs ALL products with price history, not just those with zero price

BEGIN;

-- =============================================================================
-- STEP 1: UPDATE ALL PRODUCTS WITH LATEST PRICE FROM HISTORY
-- =============================================================================

UPDATE public.products p
SET
    current_selling_price = ph.new_price,
    updated_at = NOW()
FROM (
    -- Subquery to find the most recent valid price for each product
    SELECT DISTINCT ON (product_id, store_id)
        product_id,
        store_id,
        new_price
    FROM public.price_history
    WHERE new_price > 0
    ORDER BY product_id, store_id, changed_at DESC
) AS ph
WHERE
    p.id = ph.product_id
    AND p.store_id = ph.store_id
    -- FIXED: Sync ALL products that have price history, regardless of current price
    -- This ensures products always reflect their latest price from history
    AND p.is_active = true;


-- =============================================================================
-- STEP 2: VERIFICATION AND SUMMARY
-- =============================================================================

DO $$
DECLARE
    v_total_products INTEGER;
    v_synced_products INTEGER;
    v_zero_price_products INTEGER;
BEGIN
    -- Count total active products
    SELECT COUNT(*) INTO v_total_products
    FROM public.products
    WHERE is_active = true;

    -- Count products successfully synced (have price > 0 after sync)
    SELECT COUNT(*) INTO v_synced_products
    FROM public.products p
    WHERE p.is_active = true
      AND p.current_selling_price > 0
      AND p.id IN (SELECT product_id FROM public.price_history);

    -- Count products still with zero price that have history
    SELECT COUNT(*) INTO v_zero_price_products
    FROM public.products p
    WHERE (p.current_selling_price IS NULL OR p.current_selling_price = 0)
      AND p.is_active = true
      AND p.id IN (SELECT product_id FROM public.price_history);

    -- Output summary
    RAISE NOTICE '=== PRICE SYNC SUMMARY ===';
    RAISE NOTICE 'Total active products: %', v_total_products;
    RAISE NOTICE 'Products synced with price history: %', v_synced_products;
    RAISE NOTICE 'Products with zero price (after sync): %', v_zero_price_products;

    IF v_zero_price_products = 0 THEN
        RAISE NOTICE '✅ All products with price history have been synced successfully';
    ELSE
        RAISE WARNING '⚠️ % products still have zero price despite having price history', v_zero_price_products;
    END IF;
END $$;

-- Verification query (commented - can be run manually if needed)
-- SELECT
--     p.id,
--     p.name,
--     p.store_id,
--     p.current_selling_price,
--     (SELECT new_price FROM price_history WHERE product_id = p.id ORDER BY changed_at DESC LIMIT 1) as latest_history_price
-- FROM public.products p
-- WHERE p.is_active = true
-- ORDER BY p.current_selling_price, p.name;

COMMIT;
