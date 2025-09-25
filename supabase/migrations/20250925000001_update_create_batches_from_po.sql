-- =============================================================================
-- MIGRATION: UPDATE create_batches_from_po FUNCTION
-- Cập nhật RPC function để bao gồm purchase_order_id và supplier_id
-- =============================================================================

-- Drop existing function
DROP FUNCTION IF EXISTS create_batches_from_po(UUID);

-- Recreate with enhanced functionality
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
RETURNS INTEGER AS $$
DECLARE
  po_record RECORD;
  item_record RECORD;
  batch_count INTEGER := 0;
  new_batch_number TEXT;
BEGIN
  -- Get PO info with supplier
  SELECT po.*, c.name as supplier_name
  INTO po_record
  FROM purchase_orders po
  LEFT JOIN companies c ON po.supplier_id = c.id
  WHERE po.id = po_id;

  -- Validate PO exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase Order not found with ID: %', po_id;
  END IF;

  -- Validate PO status
  IF po_record.status != 'DELIVERED' THEN
    RAISE EXCEPTION 'PO must be DELIVERED status to create batches, current status: %', po_record.status;
  END IF;

  -- Loop through PO items to create batches
  FOR item_record IN
    SELECT poi.*, p.name as product_name, p.sku as product_sku
    FROM purchase_order_items poi
    LEFT JOIN products p ON poi.product_id = p.id
    WHERE poi.purchase_order_id = po_id
    AND poi.quantity > 0
  LOOP
    -- Generate unique batch number
    new_batch_number := po_record.po_number || '-' || SUBSTRING(item_record.product_sku FROM 1 FOR 6) || '-' || LPAD(batch_count + 1::TEXT, 2, '0');

    -- Create product batch with all required fields
    INSERT INTO product_batches (
      product_id,
      batch_number,
      quantity,
      cost_price,
      received_date,
      supplier_batch_id,
      notes,
      is_available,
      purchase_order_id,
      supplier_id,
      created_at,
      updated_at
    ) VALUES (
      item_record.product_id,
      new_batch_number,
      item_record.quantity,
      item_record.unit_cost,
      po_record.delivery_date,
      po_record.po_number || '-' || item_record.product_sku,
      'Tự động tạo từ PO: ' || po_record.po_number || ' (' || po_record.supplier_name || ')',
      true,
      po_id,
      po_record.supplier_id,
      NOW(),
      NOW()
    );

    batch_count := batch_count + 1;
  END LOOP;

  -- Log the creation
  RAISE NOTICE 'Created % batches from PO %', batch_count, po_record.po_number;

  RETURN batch_count;
END;
$$ LANGUAGE plpgsql;

-- Add helpful comment
COMMENT ON FUNCTION create_batches_from_po(UUID) IS
'Creates product batches from a delivered purchase order. Returns count of batches created.';

-- =============================================================================
-- ADDITIONAL HELPER FUNCTIONS
-- =============================================================================

-- Function to get batches created from a specific PO
CREATE OR REPLACE FUNCTION get_batches_from_po(po_id UUID)
RETURNS TABLE (
  id UUID,
  batch_number TEXT,
  product_id UUID,
  product_name TEXT,
  quantity INTEGER,
  cost_price DECIMAL,
  received_date DATE,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    pb.id,
    pb.batch_number,
    pb.product_id,
    p.name as product_name,
    pb.quantity,
    pb.cost_price,
    pb.received_date,
    pb.created_at
  FROM product_batches pb
  LEFT JOIN products p ON pb.product_id = p.id
  WHERE pb.purchase_order_id = po_id
  ORDER BY pb.created_at ASC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_batches_from_po(UUID) IS
'Returns all batches created from a specific purchase order with product details.';