-- Debug: Check Price Loading Issues
-- Run this to diagnose why POS shows 0 prices after hot restart

-- =====================================================
-- 1. CHECK CURRENT DATABASE PRICES
-- =====================================================

SELECT 
    '🔍 Current Product Prices in Database' as section,
    COUNT(*) as total_products,
    COUNT(CASE WHEN current_selling_price > 0 THEN 1 END) as products_with_price,
    COUNT(CASE WHEN current_selling_price = 0 THEN 1 END) as products_with_zero_price,
    ROUND(AVG(NULLIF(current_selling_price, 0)), 0) as avg_non_zero_price
FROM products 
WHERE is_active = true;

-- =====================================================
-- 2. CHECK SPECIFIC PRODUCTS WITH ZERO PRICES
-- =====================================================

SELECT 
    '❌ Products with Zero Prices (should be fixed)' as section,
    p.name,
    p.current_selling_price,
    ph.new_price as latest_history_price,
    ph.changed_at as last_price_change
FROM products p
LEFT JOIN (
    SELECT DISTINCT ON (product_id) 
        product_id,
        new_price,
        changed_at
    FROM price_history
    ORDER BY product_id, changed_at DESC
) ph ON p.id = ph.product_id
WHERE p.is_active = true 
    AND p.current_selling_price = 0
    AND ph.new_price > 0  -- Has valid price in history but not synced
ORDER BY ph.changed_at DESC
LIMIT 10;

-- =====================================================
-- 3. FORCE SYNC PRICES FROM HISTORY
-- =====================================================

-- Update products where current_selling_price = 0 but price_history has valid price
UPDATE products p
SET 
    current_selling_price = ph.new_price,
    updated_at = NOW()
FROM (
    SELECT DISTINCT ON (product_id) 
        product_id,
        new_price
    FROM price_history
    WHERE new_price > 0
    ORDER BY product_id, changed_at DESC
) ph
WHERE p.id = ph.product_id
    AND p.current_selling_price = 0
    AND p.is_active = true;

-- =====================================================
-- 4. CHECK PRODUCTS_WITH_DETAILS VIEW
-- =====================================================

SELECT 
    '🔍 Products with Details View Sample' as section,
    name,
    current_selling_price,
    current_price,
    available_stock,
    CASE 
        WHEN current_selling_price = current_price THEN '✅ CONSISTENT'
        ELSE '❌ MISMATCH'
    END as price_consistency
FROM products_with_details
WHERE is_active = true
ORDER BY name
LIMIT 10;

-- =====================================================
-- 5. TEST RPC FUNCTIONS
-- =====================================================

-- Test get_current_price RPC for first few products
DO $$
DECLARE
    product_record RECORD;
    rpc_price NUMERIC;
    db_price NUMERIC;
BEGIN
    RAISE NOTICE '🧪 Testing get_current_price RPC vs Database:';
    
    FOR product_record IN 
        SELECT id, name, current_selling_price 
        FROM products 
        WHERE is_active = true 
        LIMIT 5
    LOOP
        SELECT get_current_price(product_record.id) INTO rpc_price;
        db_price := product_record.current_selling_price;
        
        RAISE NOTICE 'Product: % | DB: % | RPC: % | Match: %', 
            product_record.name, 
            db_price, 
            rpc_price,
            CASE WHEN db_price = rpc_price THEN '✅' ELSE '❌' END;
    END LOOP;
END $$;

-- =====================================================
-- 6. VERIFICATION AFTER SYNC
-- =====================================================

SELECT 
    '✅ Verification After Sync' as section,
    COUNT(*) as total_products,
    COUNT(CASE WHEN current_selling_price > 0 THEN 1 END) as products_with_price,
    COUNT(CASE WHEN current_selling_price = 0 THEN 1 END) as products_still_zero,
    CASE 
        WHEN COUNT(CASE WHEN current_selling_price = 0 THEN 1 END) = 0 
        THEN '🎯 ALL PRICES SYNCED!'
        ELSE '⚠️ Some products still have zero prices'
    END as sync_status
FROM products 
WHERE is_active = true;

-- =====================================================
-- 7. SAMPLE PRODUCTS FOR APP TESTING
-- =====================================================

SELECT 
    '📱 Sample Products for App Testing' as section,
    name,
    id,
    current_selling_price,
    CASE 
        WHEN current_selling_price > 0 THEN '✅ Ready for POS'
        ELSE '❌ Still zero price'
    END as pos_ready
FROM products
WHERE is_active = true
ORDER BY current_selling_price DESC
LIMIT 5;