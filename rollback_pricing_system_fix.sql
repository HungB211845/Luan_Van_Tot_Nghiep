-- ROLLBACK Migration: Fix Pricing System Mismatch
-- Date: 2025-01-27  
-- Purpose: Rollback to seasonal_prices if needed (emergency only)

-- =====================================================
-- 1. DROP CURRENT VIEWS
-- =====================================================

DROP VIEW IF EXISTS products_with_details_secure CASCADE;
DROP VIEW IF EXISTS low_stock_products CASCADE; 
DROP VIEW IF EXISTS products_with_details CASCADE;

-- =====================================================
-- 2. RESTORE OLD RPC FUNCTION get_current_price 
-- =====================================================

DROP FUNCTION IF EXISTS get_current_price(uuid) CASCADE;

-- Restore old function that reads from seasonal_prices
CREATE FUNCTION get_current_price(product_uuid uuid)
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

  -- ROLLBACK: Get price from seasonal_prices (old behavior)
  SELECT COALESCE(selling_price, 0) INTO current_price
  FROM seasonal_prices sp
  JOIN products p ON sp.product_id = p.id
  WHERE sp.product_id = product_uuid
    AND sp.store_id = current_store_id      -- CRITICAL: Filter by store
    AND p.store_id = current_store_id       -- CRITICAL: Verify product belongs to store
    AND sp.is_active = true
    AND sp.start_date <= CURRENT_DATE
    AND sp.end_date >= CURRENT_DATE
  ORDER BY sp.created_at DESC
  LIMIT 1;

  RETURN current_price;
END; $$;

-- =====================================================
-- 3. RESTORE OLD products_with_details VIEW
-- =====================================================

CREATE OR REPLACE VIEW products_with_details AS
SELECT 
    p.*,
    c.name as company_name,
    COALESCE(stock.available_stock, 0) as available_stock,
    COALESCE(price.current_price, 0) as current_price  -- ROLLBACK: Use seasonal_prices
FROM products p
LEFT JOIN companies c ON p.company_id = c.id
LEFT JOIN (
    SELECT 
        product_id,
        SUM(quantity) as available_stock
    FROM product_batches 
    WHERE is_available = true 
    AND (expiry_date IS NULL OR expiry_date > CURRENT_DATE)
    GROUP BY product_id
) stock ON p.id = stock.product_id
LEFT JOIN (
    SELECT DISTINCT ON (product_id) 
        product_id,
        selling_price as current_price
    FROM seasonal_prices 
    WHERE start_date <= CURRENT_DATE
    AND end_date >= CURRENT_DATE
    AND is_active = true
    ORDER BY product_id, start_date DESC
) price ON p.id = price.product_id;

-- =====================================================
-- 4. RESTORE OTHER VIEWS
-- =====================================================

CREATE VIEW low_stock_products AS
SELECT
  p.*,
  get_available_stock(p.id) as available_stock,
  get_current_price(p.id) as current_price  -- ROLLBACK: Use RPC
FROM products p
WHERE p.store_id = (
  SELECT store_id FROM user_profiles WHERE id = auth.uid()
)
AND get_available_stock(p.id) <= p.min_stock_level;

CREATE OR REPLACE VIEW products_with_details_secure AS
SELECT
  p.*,
  get_current_price(p.id) as current_price,
  get_available_stock(p.id) as available_stock,
  c.name as company_name,
  CASE WHEN p.store_id = (
    SELECT store_id FROM user_profiles WHERE id = auth.uid()
  ) THEN true ELSE false END as accessible
FROM products p
LEFT JOIN companies c ON p.company_id = c.id
WHERE p.store_id = (
  SELECT store_id FROM user_profiles WHERE id = auth.uid()
);

-- =====================================================
-- 5. GRANT PERMISSIONS
-- =====================================================

GRANT EXECUTE ON FUNCTION get_current_price(uuid) TO authenticated;
GRANT SELECT ON products_with_details TO authenticated;  
GRANT SELECT ON low_stock_products TO authenticated;
GRANT SELECT ON products_with_details_secure TO authenticated;