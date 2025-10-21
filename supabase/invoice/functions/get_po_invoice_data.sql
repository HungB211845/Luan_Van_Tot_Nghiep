-- RPC Function: Get complete invoice data for a purchase order
-- Usage: SELECT * FROM get_po_invoice_data('po-uuid');

CREATE OR REPLACE FUNCTION public.get_po_invoice_data(
  p_po_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
  v_store_id UUID;
BEGIN
  -- Get user's store_id for security
  SELECT store_id INTO v_store_id
  FROM public.user_profiles
  WHERE id = auth.uid();

  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'User not associated with any store';
  END IF;

  -- Build complete PO invoice data
  SELECT json_build_object(
    'store_info', (
      SELECT row_to_json(sbi.*)
      FROM public.store_business_info sbi
      WHERE sbi.store_id = v_store_id
      LIMIT 1
    ),
    'purchase_order', (
      SELECT row_to_json(po.*)
      FROM public.purchase_orders po
      WHERE po.id = p_po_id
        AND po.store_id = v_store_id
      LIMIT 1
    ),
    'supplier', (
      SELECT row_to_json(c.*)
      FROM public.purchase_orders po
      LEFT JOIN public.companies c ON po.supplier_id = c.id
      WHERE po.id = p_po_id
        AND po.store_id = v_store_id
      LIMIT 1
    ),
    'items', (
      SELECT json_agg(
        json_build_object(
          'id', poi.id,
          'product_id', poi.product_id,
          'product_name', poi.product_name,
          'quantity', poi.quantity,
          'unit', poi.unit,
          'unit_cost', poi.unit_cost,
          'selling_price', poi.selling_price,
          'total_cost', poi.total_cost,
          'received_quantity', poi.received_quantity
        )
      )
      FROM public.purchase_order_items poi
      WHERE poi.purchase_order_id = p_po_id
        AND poi.store_id = v_store_id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_po_invoice_data(UUID) TO authenticated;

-- Comment
COMMENT ON FUNCTION public.get_po_invoice_data(UUID) IS
  'Get complete invoice data for a purchase order (store info, PO, supplier, items)';
