-- Test Pricing System Consistency
-- Run this after applying fix_pricing_system_mismatch.sql

-- =====================================================
-- 1. CHECK ALL PRICING SOURCES ARE CONSISTENT
-- =====================================================

SELECT 
  p.name,
  p.sku,
  p.current_selling_price as "Column_Price",
  get_current_price(p.id) as "RPC_Price", 
  pwd.current_price as "View_Price",
  CASE 
    WHEN p.current_selling_price = get_current_price(p.id) 
     AND p.current_selling_price = pwd.current_price 
    THEN '✅ CONSISTENT' 
    ELSE '❌ MISMATCH' 
  END as status,
  CASE
    WHEN p.current_selling_price != get_current_price(p.id) THEN 'Column vs RPC mismatch'
    WHEN p.current_selling_price != pwd.current_price THEN 'Column vs View mismatch'  
    WHEN get_current_price(p.id) != pwd.current_price THEN 'RPC vs View mismatch'
    ELSE 'All consistent'
  END as issue_type
FROM products p
JOIN products_with_details pwd ON p.id = pwd.id
WHERE p.is_active = true
ORDER BY status DESC, p.name
LIMIT 10;

-- =====================================================
-- 2. CHECK ZERO PRICE PRODUCTS
-- =====================================================

SELECT 
  'Zero Price Products' as check_type,
  COUNT(*) as count,
  STRING_AGG(p.name, ', ') as product_names
FROM products p
WHERE p.is_active = true 
AND p.current_selling_price = 0;

-- =====================================================
-- 3. CHECK RPC FUNCTION BEHAVIOR
-- =====================================================

SELECT 
  'RPC Function Test' as check_type,
  p.name,
  p.current_selling_price as expected,
  get_current_price(p.id) as actual,
  CASE 
    WHEN get_current_price(p.id) = p.current_selling_price THEN '✅ PASS'
    ELSE '❌ FAIL'
  END as test_result
FROM products p
WHERE p.is_active = true
AND p.current_selling_price > 0
LIMIT 5;

-- =====================================================
-- 4. CHECK VIEW PERFORMANCE
-- =====================================================

EXPLAIN (ANALYZE, BUFFERS) 
SELECT p.*, pwd.current_price, pwd.available_stock
FROM products p
JOIN products_with_details pwd ON p.id = pwd.id
WHERE p.is_active = true
LIMIT 100;

-- =====================================================
-- 5. SUMMARY STATISTICS
-- =====================================================

SELECT 
  'Summary Statistics' as section,
  COUNT(*) as total_products,
  COUNT(CASE WHEN current_selling_price > 0 THEN 1 END) as products_with_price,
  COUNT(CASE WHEN current_selling_price = 0 THEN 1 END) as products_without_price,
  AVG(current_selling_price) as avg_price,
  MIN(current_selling_price) as min_price,
  MAX(current_selling_price) as max_price
FROM products 
WHERE is_active = true;

-- =====================================================
-- 6. TEST POS INTEGRATION
-- =====================================================

-- This simulates what POS would do when loading products
SELECT 
  'POS Integration Test' as test_name,
  p.id,
  p.name,
  p.current_selling_price as pos_will_use_this_price,
  get_available_stock(p.id) as available_stock,
  CASE 
    WHEN p.current_selling_price > 0 AND get_available_stock(p.id) > 0 THEN '✅ Ready for POS'
    WHEN p.current_selling_price = 0 THEN '⚠️ No price set'
    WHEN get_available_stock(p.id) = 0 THEN '⚠️ Out of stock'
    ELSE '❌ Not ready'
  END as pos_status
FROM products p
WHERE p.is_active = true
ORDER BY pos_status, p.name
LIMIT 20;