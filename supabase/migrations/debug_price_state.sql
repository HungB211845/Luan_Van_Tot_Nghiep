-- =============================================================================
-- DEBUG: Check Price State After Migration
-- Date: 2025-10-05
-- Purpose: Verify database state and price sync results
-- =============================================================================

-- Check products table current_selling_price values
SELECT
    id,
    name,
    sku,
    current_selling_price,
    created_at,
    updated_at
FROM products
WHERE name ILIKE '%NPK%' OR name ILIKE '%Đậu%'
ORDER BY name;

-- Check latest price history for these products
SELECT
    ph.product_id,
    p.name as product_name,
    ph.new_price,
    ph.old_price,
    ph.reason,
    ph.changed_at,
    ph.changed_by
FROM price_history ph
JOIN products p ON ph.product_id = p.id
WHERE p.name ILIKE '%NPK%' OR p.name ILIKE '%Đậu%'
ORDER BY p.name, ph.changed_at DESC
LIMIT 20;

-- Check count of products with zero prices
SELECT
    COUNT(*) as total_products,
    COUNT(CASE WHEN current_selling_price = 0 THEN 1 END) as zero_price_products,
    COUNT(CASE WHEN current_selling_price > 0 THEN 1 END) as non_zero_price_products,
    AVG(current_selling_price) as avg_price
FROM products
WHERE is_active = true;

-- Show products that have price history but zero current_selling_price
SELECT
    p.id,
    p.name,
    p.current_selling_price,
    COUNT(ph.id) as price_history_count,
    MAX(ph.new_price) as latest_price_in_history,
    MAX(ph.changed_at) as latest_price_change
FROM products p
LEFT JOIN price_history ph ON p.id = ph.product_id
WHERE p.is_active = true
GROUP BY p.id, p.name, p.current_selling_price
HAVING COUNT(ph.id) > 0 AND p.current_selling_price = 0
ORDER BY price_history_count DESC;