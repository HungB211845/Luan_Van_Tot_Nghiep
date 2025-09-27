-- =============================================================================
-- FIXED: STORE-AWARE RPC FUNCTIONS FOR PO WORKFLOW
-- =============================================================================

-- 1) Store-aware create_batches_from_po
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  batch_count integer := 0;
  current_store_id uuid;
BEGIN
  -- SECURITY: Get current user's store_id
  SELECT store_id INTO current_store_id
  FROM user_profiles
  WHERE id = auth.uid();

  IF current_store_id IS NULL THEN
    RAISE EXCEPTION 'User must belong to a store';
  END IF;

  -- SECURITY: Verify PO belongs to user's store
  IF NOT EXISTS (
    SELECT 1 FROM purchase_orders
    WHERE id = po_id AND store_id = current_store_id
  ) THEN
    RAISE EXCEPTION 'Purchase order not found or access denied';
  END IF;

  -- Create batches with store_id validation
  INSERT INTO product_batches (
    product_id, quantity, cost_price, received_date, batch_number,
    purchase_order_id, is_available, notes, created_at, updated_at, store_id
  )
  SELECT
    poi.product_id,
    COALESCE(NULLIF(poi.received_quantity, 0), poi.quantity) as quantity,
    poi.unit_cost,
    COALESCE(po.delivery_date, CURRENT_DATE) as received_date,
    'BATCH-' || TO_CHAR(NOW(),'YYYYMMDD') || '-' || SUBSTR(gen_random_uuid()::text,1,8),
    po_id,
    true,
    'Auto-created from PO #' || COALESCE(po.po_number, po.id::text),
    NOW(), NOW(),
    current_store_id  -- CRITICAL: Set store_id
  FROM purchase_order_items poi
  JOIN purchase_orders po ON poi.purchase_order_id = po.id
  JOIN products p ON poi.product_id = p.id
  WHERE po.id = po_id
    AND po.store_id = current_store_id  -- SECURITY: Double-check store
    AND p.store_id = current_store_id   -- SECURITY: Verify products belong to store
    AND COALESCE(NULLIF(poi.received_quantity,0), poi.quantity) > 0;

  GET DIAGNOSTICS batch_count = ROW_COUNT;
  UPDATE purchase_orders SET updated_at = NOW() WHERE id = po_id AND store_id = current_store_id;
  RETURN batch_count;
END; $$;

-- 2) Store-aware get_available_stock
-- Drop dependent views first
DROP VIEW IF EXISTS low_stock_products CASCADE;
DROP FUNCTION IF EXISTS get_available_stock(uuid) CASCADE;
CREATE FUNCTION get_available_stock(product_uuid uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  total_stock integer := 0;
  current_store_id uuid;
BEGIN
  -- SECURITY: Get current user's store_id
  SELECT store_id INTO current_store_id
  FROM user_profiles
  WHERE id = auth.uid();

  IF current_store_id IS NULL THEN
    RETURN 0; -- No access without store
  END IF;

  -- SECURITY: Only count stock from user's store
  SELECT COALESCE(SUM(quantity), 0) INTO total_stock
  FROM product_batches pb
  JOIN products p ON pb.product_id = p.id
  WHERE pb.product_id = product_uuid
    AND pb.store_id = current_store_id    -- CRITICAL: Filter by store
    AND p.store_id = current_store_id     -- CRITICAL: Verify product belongs to store
    AND pb.is_available = true
    AND pb.quantity > 0
    AND (pb.expiry_date IS NULL OR pb.expiry_date > CURRENT_DATE);

  RETURN total_stock;
END; $$;

-- 3) Store-aware get_current_price
DROP FUNCTION IF EXISTS get_current_price(uuid);
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

  -- SECURITY: Only get prices from user's store
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

-- 4) Store-aware products_with_details view (if needed)
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

-- Recreate low_stock_products view with store awareness
CREATE VIEW low_stock_products AS
SELECT
  p.*,
  get_available_stock(p.id) as available_stock,
  get_current_price(p.id) as current_price
FROM products p
WHERE p.store_id = (
  SELECT store_id FROM user_profiles WHERE id = auth.uid()
)
AND get_available_stock(p.id) <= p.min_stock_level;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_batches_from_po(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_stock(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_price(uuid) TO authenticated;
GRANT SELECT ON products_with_details_secure TO authenticated;
GRANT SELECT ON low_stock_products TO authenticated;