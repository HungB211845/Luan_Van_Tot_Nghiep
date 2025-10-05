-- Debug script to check price sync status
-- Run this in Supabase SQL Editor to diagnose the issue
-- =====================================================
-- 1. CHECK PRODUCTS WITH ZERO PRICES
-- =====================================================
SELECT
    p.id,
    p.name,
    p.sku,
    p.current_selling_price as "Current Price",
    ph.latest_price as "Latest History Price",
    ph.changed_at as "Last Updated",
    CASE
        WHEN p.current_selling_price = 0
        AND ph.latest_price > 0 THEN '❌ NEEDS SYNC'
        WHEN p.current_selling_price > 0 THEN '✅ OK'
        ELSE '⚠️ NO HISTORY'
    END as "Status"
FROM
    products p
    LEFT JOIN (
        SELECT DISTINCT
            ON (product_id) product_id,
            new_price as latest_price,
            changed_at
        FROM
            price_history
        WHERE
            new_price > 0
        ORDER BY
            product_id,
            changed_at DESC
    ) ph ON p.id = ph.product_id
WHERE
    p.is_active = true
ORDER BY
    p.current_selling_price ASC,
    p.name;

-- =====================================================
-- 2. MANUAL SYNC FOR PRODUCTS WITH MISSING PRICES
-- =====================================================
UPDATE products p
SET
    current_selling_price = ph.latest_price,
    updated_at = NOW ()
FROM
    (
        SELECT DISTINCT
            ON (product_id) product_id,
            new_price as latest_price
        FROM
            price_history
        WHERE
            new_price > 0
        ORDER BY
            product_id,
            changed_at DESC
    ) ph
WHERE
    p.id = ph.product_id
    AND p.current_selling_price = 0
    AND p.is_active = true;

-- =====================================================
-- 3. VERIFICATION
-- =====================================================
SELECT
    COUNT(*) as total_active_products,
    COUNT(
        CASE
            WHEN current_selling_price > 0 THEN 1
        END
    ) as products_with_price,
    COUNT(
        CASE
            WHEN current_selling_price = 0 THEN 1
        END
    ) as products_zero_price
FROM
    products
WHERE
    is_active = true;