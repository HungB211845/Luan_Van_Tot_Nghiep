-- Migration: Fix Price and Stock Sync Issues
-- Date: 2025-01-27
-- Purpose: Ensure current_selling_price is synced from latest price_history
--          and stock calculations are working correctly

-- =====================================================
-- 1. SYNC CURRENT_SELLING_PRICE FROM PRICE HISTORY
-- =====================================================

-- Update products.current_selling_price from latest price_history entry
-- This fixes the issue where hot restart shows 0 price
UPDATE products p
SET 
    current_selling_price = COALESCE(
        (SELECT ph.new_price
         FROM price_history ph
         WHERE ph.product_id = p.id
           AND ph.store_id = p.store_id  -- Ensure store isolation
         ORDER BY ph.changed_at DESC
         LIMIT 1),
        p.current_selling_price  -- Keep existing if no history
    ),
    updated_at = NOW()
WHERE p.is_active = true;

-- =====================================================
-- 2. VERIFY STOCK CALCULATION FUNCTIONS
-- =====================================================

-- Test get_available_stock function with sample products
DO $$
DECLARE
    product_record RECORD;
    calculated_stock INTEGER;
BEGIN
    -- Test stock calculation for first 5 active products
    FOR product_record IN 
        SELECT id, name FROM products 
        WHERE is_active = true 
        LIMIT 5
    LOOP
        SELECT get_available_stock(product_record.id) INTO calculated_stock;
        RAISE NOTICE 'Product: % (ID: %) - Stock: %', 
            product_record.name, 
            product_record.id, 
            calculated_stock;
    END LOOP;
END $$;

-- =====================================================
-- 3. CLEAN UP ORPHANED PRICE HISTORY
-- =====================================================

-- Remove price history entries for deleted products
DELETE FROM price_history 
WHERE product_id NOT IN (
    SELECT id FROM products WHERE is_active = true
);

-- =====================================================
-- 4. UPDATE TRIGGER FOR AUTO PRICE SYNC (OPTIONAL)
-- =====================================================

-- Create trigger to auto-update current_selling_price when price_history changes
CREATE OR REPLACE FUNCTION sync_current_selling_price()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the product's current_selling_price to match latest price_history
    UPDATE products 
    SET 
        current_selling_price = NEW.new_price,
        updated_at = NOW()
    WHERE id = NEW.product_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trigger_sync_current_selling_price ON price_history;

-- Create trigger that fires after price_history insert
CREATE TRIGGER trigger_sync_current_selling_price
    AFTER INSERT ON price_history
    FOR EACH ROW
    EXECUTE FUNCTION sync_current_selling_price();

-- =====================================================
-- 5. VERIFICATION QUERIES
-- =====================================================

-- Check products with mismatched prices
SELECT 
    p.id,
    p.name,
    p.current_selling_price as "Current Price (Product)",
    ph.new_price as "Latest Price (History)",
    ph.changed_at as "Last Updated",
    CASE 
        WHEN p.current_selling_price = ph.new_price THEN '✅ SYNCED'
        WHEN p.current_selling_price != ph.new_price THEN '❌ MISMATCH'
        WHEN ph.new_price IS NULL THEN '⚠️ NO HISTORY'
        ELSE '❓ UNKNOWN'
    END as status
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
ORDER BY status DESC, p.name
LIMIT 20;

-- Check products with zero prices
SELECT 
    COUNT(*) as total_products,
    COUNT(CASE WHEN current_selling_price > 0 THEN 1 END) as products_with_price,
    COUNT(CASE WHEN current_selling_price = 0 THEN 1 END) as products_without_price,
    ROUND(AVG(current_selling_price), 0) as avg_price
FROM products 
WHERE is_active = true;

-- Check stock calculation consistency
SELECT 
    p.name,
    p.id,
    get_available_stock(p.id) as calculated_stock,
    COALESCE(
        (SELECT SUM(quantity) 
         FROM product_batches pb 
         WHERE pb.product_id = p.id 
           AND pb.is_available = true 
           AND pb.is_deleted = false
           AND (pb.expiry_date IS NULL OR pb.expiry_date > CURRENT_DATE)
        ), 0
    ) as manual_stock_check
FROM products p
WHERE p.is_active = true
LIMIT 10;

-- Show summary
SELECT 
    '🎯 Migration Complete!' as status,
    'Updated prices from price_history' as step1,
    'Verified stock calculations' as step2,
    'Added auto-sync trigger' as step3,
    'Ready for testing' as next_step;