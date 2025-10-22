-- RPC Function: Get complete invoice data for a purchase order (with VAT support)
-- Usage: SELECT * FROM get_po_invoice_data('po-uuid');
-- Updated: 2025-10-22 - Added VAT fields and supplier full info per NĐ 123/2020

CREATE OR REPLACE FUNCTION public.get_po_invoice_data(
  p_po_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
  v_store_id UUID;
  v_default_vat_rate NUMERIC(5,2);
  v_order_date TIMESTAMPTZ;
BEGIN
  -- Get user's store_id for security
  SELECT store_id INTO v_store_id
  FROM public.user_profiles
  WHERE id = auth.uid();

  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'User not associated with any store';
  END IF;

  -- Get store's default VAT rate
  SELECT COALESCE(default_vat_rate, 0) INTO v_default_vat_rate
  FROM public.store_business_info
  WHERE store_id = v_store_id
  LIMIT 1;

  -- Get PO order date for price sheet reference
  SELECT order_date INTO v_order_date
  FROM public.purchase_orders
  WHERE id = p_po_id
    AND store_id = v_store_id
  LIMIT 1;

  -- Build complete PO invoice data with VAT calculations
  SELECT json_build_object(
    'store_info', (
      SELECT row_to_json(sbi.*)
      FROM public.store_business_info sbi
      WHERE sbi.store_id = v_store_id
      LIMIT 1
    ),
    'purchase_order', (
      SELECT json_build_object(
        'id', po.id,
        'supplier_id', po.supplier_id,
        'po_number', po.po_number,
        'order_date', po.order_date,
        'expected_delivery_date', po.expected_delivery_date,
        'delivery_date', po.delivery_date,
        'status', LOWER(po.status),  -- Convert DRAFT/SENT/etc to lowercase for Dart enum
        'subtotal', po.subtotal,
        'tax_amount', po.tax_amount,
        'total_amount', po.total_amount,
        'discount_amount', po.discount_amount,
        'payment_terms', po.payment_terms,
        'notes', po.notes,
        'created_by', po.created_by,
        'store_id', po.store_id,
        'created_at', po.created_at,
        'updated_at', po.updated_at  -- CRITICAL: Required by PurchaseOrder.fromMap()
      )
      FROM public.purchase_orders po
      WHERE po.id = p_po_id
        AND po.store_id = v_store_id
      LIMIT 1
    ),
    'supplier', (
      SELECT json_build_object(
        'id', c.id,
        'name', c.name,
        'address', c.address,
        'phone', c.phone,
        'contact_person', c.contact_person,
        'note', c.note,
        'store_id', c.store_id,
        'is_active', c.is_active,
        'created_at', c.created_at,
        'updated_at', c.updated_at,
        'tax_code', NULL  -- Placeholder until supplier tax code is tracked
      )
      FROM public.companies c
      WHERE c.id = (
        SELECT supplier_id
        FROM public.purchase_orders
        WHERE id = p_po_id
        AND store_id = v_store_id
      )
      LIMIT 1
    ),
    'items', (
      SELECT json_agg(
        json_build_object(
          'id', poi.id,
          'purchase_order_id', poi.purchase_order_id,
          'product_id', poi.product_id,
          'product_name', p.name,
          'product_sku', p.sku,
          'quantity', poi.quantity,
          'unit', poi.unit,
          'unit_cost', poi.unit_cost,
          'total_cost', poi.total_cost,
          'selling_price', poi.selling_price,
          'received_quantity', poi.received_quantity,
          'notes', poi.notes,
          'store_id', poi.store_id,
          'created_at', poi.created_at,
          -- VAT fields (using store default rate)
          'tax_rate', v_default_vat_rate,
          'tax_amount', ROUND((poi.total_cost * v_default_vat_rate / 100)::numeric, 0),
          'gross_amount', poi.total_cost + ROUND((poi.total_cost * v_default_vat_rate / 100)::numeric, 0)
        )
      )
      FROM public.purchase_order_items poi
      LEFT JOIN public.products p ON poi.product_id = p.id
      WHERE poi.purchase_order_id = p_po_id
        AND poi.store_id = v_store_id
    ),
    'vat_total', (
      SELECT COALESCE(SUM(ROUND((poi.total_cost * v_default_vat_rate / 100)::numeric, 0)), 0)
      FROM public.purchase_order_items poi
      WHERE poi.purchase_order_id = p_po_id
        AND poi.store_id = v_store_id
    )
  )
  INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_po_invoice_data(UUID) TO authenticated;

-- Comment
COMMENT ON FUNCTION public.get_po_invoice_data(UUID) IS
  'Get complete invoice data for a purchase order (store info, PO, supplier, items with VAT)';
