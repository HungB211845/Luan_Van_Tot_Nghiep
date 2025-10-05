-- =============================================================================
-- VERIFICATION QUERY - Check Price State After Migrations (FIXED VERSION)
-- Run this in Supabase SQL Editor to verify current state
-- =============================================================================

-- Query 1: Count products and their price state
SELECT
    'Total Active Products' as metric,
    COUNT(*) as count
FROM public.products
WHERE is_active = true

UNION ALL

SELECT
    'Products with price > 0' as metric,
    COUNT(*) as count
FROM public.products
WHERE is_active = true
  AND current_selling_price > 0

UNION ALL

SELECT
    'Products with price = 0 or NULL' as metric,
    COUNT(*) as count
FROM public.products
WHERE is_active = true
  AND (current_selling_price = 0 OR current_selling_price IS NULL)

UNION ALL

SELECT
    'Total Price History Entries' as metric,
    COUNT(*) as count
FROM public.price_history

UNION ALL

SELECT
    'Unique Products with Price History' as metric,
    COUNT(DISTINCT product_id) as count
FROM public.price_history;

-- =============================================================================
-- Query 2: Show products with their current price vs latest history price
-- =============================================================================

WITH latest_prices AS (
    SELECT DISTINCT ON (product_id, store_id)
        product_id,
        store_id,
        new_price as latest_price,
        changed_at as last_changed
    FROM public.price_history
    WHERE new_price > 0
    ORDER BY product_id, store_id, changed_at DESC
)
SELECT
    p.id,
    p.name,
    p.sku,
    p.current_selling_price as product_table_price,
    lp.latest_price as latest_history_price,
    lp.last_changed as last_price_change,
    CASE
        WHEN p.current_selling_price = lp.latest_price THEN '✅ SYNCED'
        WHEN p.current_selling_price IS NULL OR p.current_selling_price = 0 THEN '⚠️ NO PRICE'
        WHEN lp.latest_price IS NULL THEN '📋 NO HISTORY'
        ELSE '❌ MISMATCH'
    END as sync_status
FROM public.products p
LEFT JOIN latest_prices lp ON p.id = lp.product_id AND p.store_id = lp.store_id
WHERE p.is_active = true
ORDER BY
    CASE
        WHEN p.current_selling_price = lp.latest_price THEN 4
        WHEN p.current_selling_price IS NULL OR p.current_selling_price = 0 THEN 2
        WHEN lp.latest_price IS NULL THEN 3
        ELSE 1
    END,
    p.name
LIMIT 50;

-- =============================================================================
-- Query 3: Show recent price history entries (check actual columns first)
-- =============================================================================

-- First, check what columns exist in price_history table
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'price_history'
ORDER BY ordinal_position;

-- =============================================================================
-- Query 4: Show recent price changes (simplified without user join)
-- =============================================================================

SELECT
    ph.id,
    p.name as product_name,
    p.sku,
    ph.old_price,
    ph.new_price,
    ph.reason,
    ph.changed_at,
    ph.store_id
FROM public.price_history ph
JOIN public.products p ON ph.product_id = p.id AND ph.store_id = p.store_id
ORDER BY ph.changed_at DESC
LIMIT 20;
