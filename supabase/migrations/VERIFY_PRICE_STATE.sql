-- =============================================================================
-- VERIFICATION QUERY - Check Price State After Migrations
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

-- Query 2: Show products with their current price vs latest history price
SELECT
    p.id,
    p.name,
    p.sku,
    p.current_selling_price as product_table_price,
    (
        SELECT new_price
        FROM public.price_history ph
        WHERE ph.product_id = p.id
          AND ph.store_id = p.store_id
        ORDER BY changed_at DESC
        LIMIT 1
    ) as latest_history_price,
    (
        SELECT changed_at
        FROM public.price_history ph
        WHERE ph.product_id = p.id
          AND ph.store_id = p.store_id
        ORDER BY changed_at DESC
        LIMIT 1
    ) as last_price_change,
    CASE
        WHEN p.current_selling_price = (
            SELECT new_price
            FROM public.price_history ph
            WHERE ph.product_id = p.id
              AND ph.store_id = p.store_id
            ORDER BY changed_at DESC
            LIMIT 1
        ) THEN '✅ SYNCED'
        WHEN p.current_selling_price IS NULL OR p.current_selling_price = 0 THEN '⚠️ NO PRICE'
        WHEN (
            SELECT new_price
            FROM public.price_history ph
            WHERE ph.product_id = p.id
              AND ph.store_id = p.store_id
            ORDER BY changed_at DESC
            LIMIT 1
        ) IS NULL THEN '📋 NO HISTORY'
        ELSE '❌ MISMATCH'
    END as sync_status
FROM public.products p
WHERE p.is_active = true
ORDER BY
    CASE sync_status
        WHEN '❌ MISMATCH' THEN 1
        WHEN '⚠️ NO PRICE' THEN 2
        WHEN '📋 NO HISTORY' THEN 3
        WHEN '✅ SYNCED' THEN 4
    END,
    p.name
LIMIT 50;

-- Query 3: Show recent price history entries (if any)
SELECT
    ph.id,
    p.name as product_name,
    p.sku,
    ph.old_price,
    ph.new_price,
    ph.reason,
    ph.changed_at,
    u.email as changed_by_user
FROM public.price_history ph
JOIN public.products p ON ph.product_id = p.id
LEFT JOIN auth.users u ON ph.changed_by = u.id
ORDER BY ph.changed_at DESC
LIMIT 20;
