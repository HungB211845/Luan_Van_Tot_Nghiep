-- =============================================================================
-- CREATE MISSING VIEWS: expiring_batches & fix low_stock_products
-- =============================================================================

-- 1) Create expiring_batches view
CREATE OR REPLACE VIEW expiring_batches AS
SELECT
  pb.*,
  p.name as product_name,
  p.sku as product_sku,
  c.name as company_name,
  -- Calculate days until expiry
  CASE
    WHEN pb.expiry_date IS NULL THEN NULL
    ELSE (pb.expiry_date - CURRENT_DATE)::integer
  END as days_until_expiry,
  -- Include store_id for RLS filtering
  pb.store_id
FROM product_batches pb
LEFT JOIN products p ON pb.product_id = p.id
LEFT JOIN companies c ON p.company_id = c.id
WHERE pb.is_available = true
  AND pb.quantity > 0
  AND pb.expiry_date IS NOT NULL
  AND pb.expiry_date <= CURRENT_DATE + INTERVAL '3 months'  -- Default 3 months window
  AND pb.store_id = (
    SELECT store_id FROM user_profiles WHERE id = auth.uid()
  );

-- 2) Fix low_stock_products view to use current_stock instead of available_stock
DROP VIEW IF EXISTS low_stock_products CASCADE;
CREATE VIEW low_stock_products AS
SELECT
  p.*,
  get_available_stock(p.id) as current_stock,  -- Use current_stock alias
  get_available_stock(p.id) as available_stock, -- Keep available_stock for backward compatibility
  get_current_price(p.id) as current_price,
  c.name as company_name
FROM products p
LEFT JOIN companies c ON p.company_id = c.id
WHERE p.store_id = (
  SELECT store_id FROM user_profiles WHERE id = auth.uid()
)
AND get_available_stock(p.id) <= p.min_stock_level;

-- 3) Create get_expiring_batches_report RPC function
CREATE OR REPLACE FUNCTION get_expiring_batches_report(p_months integer DEFAULT 3)
RETURNS TABLE(
  id uuid,
  product_id uuid,
  product_name text,
  product_sku text,
  company_name text,
  batch_number text,
  quantity integer,
  expiry_date date,
  days_until_expiry integer,
  cost_price numeric,
  received_date date,
  store_id uuid
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  current_store_id uuid;
BEGIN
  -- SECURITY: Get current user's store_id
  SELECT store_id INTO current_store_id
  FROM user_profiles
  WHERE id = auth.uid();

  IF current_store_id IS NULL THEN
    RETURN; -- No access without store
  END IF;

  -- Return expiring batches for user's store only
  RETURN QUERY
  SELECT
    pb.id,
    pb.product_id,
    p.name as product_name,
    p.sku as product_sku,
    c.name as company_name,
    pb.batch_number,
    pb.quantity,
    pb.expiry_date,
    CASE
      WHEN pb.expiry_date IS NULL THEN NULL
      ELSE (pb.expiry_date - CURRENT_DATE)::integer
    END as days_until_expiry,
    pb.cost_price,
    pb.received_date,
    pb.store_id
  FROM product_batches pb
  LEFT JOIN products p ON pb.product_id = p.id
  LEFT JOIN companies c ON p.company_id = c.id
  WHERE pb.is_available = true
    AND pb.quantity > 0
    AND pb.expiry_date IS NOT NULL
    AND pb.expiry_date <= CURRENT_DATE + (p_months || ' months')::interval
    AND pb.store_id = current_store_id  -- SECURITY: Filter by store
    AND p.store_id = current_store_id   -- SECURITY: Verify product belongs to store
  ORDER BY pb.expiry_date ASC;
END; $$;

-- Grant permissions
GRANT SELECT ON expiring_batches TO authenticated;
GRANT SELECT ON low_stock_products TO authenticated;
GRANT EXECUTE ON FUNCTION get_expiring_batches_report(integer) TO authenticated;