-- Migration: Fix Pricing System Mismatch
-- Date: 2025-01-27  
-- Purpose: Update all pricing functions to use products.current_selling_price instead of seasonal_prices

-- =====================================================
-- 1. DROP DEPENDENT VIEWS FIRST
-- =====================================================

-- Drop all views that depend on get_current_price function
DROP VIEW IF EXISTS products_with_details_secure CASCADE;
DROP VIEW IF EXISTS low_stock_products CASCADE; 
DROP VIEW IF EXISTS products_with_details CASCADE;

-- =====================================================
-- 2. UPDATE RPC FUNCTION get_current_price 
-- =====================================================

-- Now we can safely drop and recreate the function
DROP FUNCTION IF EXISTS get_current_price(uuid) CASCADE;

-- Create new function that reads from products.current_selling_price
CREATE OR REPLACE FUNCTION get_current_price(product_uuid uuid)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  current_price numeric := 0;
  current_store_id uuid;
BEGIN
  -- SECURITY: Get current user's store_id
  SELECT store_id INTO current_store_id
  FROM user_profiles
  WHERE id = auth.uid();

  IF current_store_id IS NULL THEN
    RETURN 0; -- No access without store
  END IF;

  -- FIXED: Get price from products.current_selling_price column
  SELECT COALESCE(current_selling_price, 0) INTO current_price
  FROM products
  WHERE id = product_uuid
    AND store_id = current_store_id      -- CRITICAL: Filter by store
    AND is_active = true;

  RETURN current_price;
END; $$;

-- =====================================================
-- 3. RECREATE products_with_details VIEW
-- =====================================================

-- Recreate view using products.current_selling_price
CREATE OR REPLACE VIEW products_with_details AS
SELECT 
    p.*,
    c.name as company_name,
    COALESCE(stock.available_stock, 0) as available_stock,
    p.current_selling_price as current_price  -- FIXED: Use column directly
FROM products p
LEFT JOIN companies c ON p.company_id = c.id
LEFT JOIN (
    SELECT 
        product_id,
        SUM(quantity) as available_stock
    FROM product_batches 
    WHERE is_available = true 
    AND is_deleted = false
    AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
    GROUP BY product_id
) stock ON p.id = stock.product_id;

-- =====================================================
-- 4. RECREATE low_stock_products VIEW 
-- =====================================================
-- Recreate low_stock_products view with store awareness
CREATE VIEW low_stock_products AS
SELECT
  p.*,
  get_available_stock(p.id) as available_stock,
  p.current_selling_price as current_price  -- FIXED: Use column directly
FROM products p
WHERE p.store_id = (
  SELECT store_id FROM user_profiles WHERE id = auth.uid()
)
AND get_available_stock(p.id) <= p.min_stock_level
AND p.is_active = true;

-- =====================================================
-- 5. RECREATE products_with_details_secure VIEW (if exists)
-- =====================================================

-- This view might exist from previous migrations
CREATE OR REPLACE VIEW products_with_details_secure AS
SELECT
  p.*,
  get_current_price(p.id) as current_price,
  get_available_stock(p.id) as available_stock,
  c.name as company_name,
  -- Only show products from current user's store
  CASE WHEN p.store_id = (
    SELECT store_id FROM user_profiles WHERE id = auth.uid()
  ) THEN true ELSE false END as accessible
FROM products p
LEFT JOIN companies c ON p.company_id = c.id
WHERE p.store_id = (
  SELECT store_id FROM user_profiles WHERE id = auth.uid()
);

-- =====================================================
-- 6. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION get_current_price(uuid) TO authenticated;
GRANT SELECT ON products_with_details TO authenticated;  
GRANT SELECT ON low_stock_products TO authenticated;
GRANT SELECT ON products_with_details_secure TO authenticated;

-- =====================================================
-- 7. VERIFICATION QUERY
-- =====================================================

-- Test the fix works correctly
SELECT 
  p.name,
  p.current_selling_price as "products.current_selling_price",
  get_current_price(p.id) as "rpc_get_current_price",
  pwd.current_price as "view_current_price",
  CASE 
    WHEN p.current_selling_price = get_current_price(p.id) 
     AND p.current_selling_price = pwd.current_price 
    THEN '✅ CONSISTENT' 
    ELSE '❌ MISMATCH' 
  END as status
FROM products p
JOIN products_with_details pwd ON p.id = pwd.id
WHERE p.is_active = true
LIMIT 5;