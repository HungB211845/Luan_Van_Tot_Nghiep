-- RPC Function: Get complete invoice data for a transaction
-- Usage: SELECT * FROM get_invoice_data('transaction-uuid');

CREATE OR REPLACE FUNCTION public.get_invoice_data(
  p_transaction_id UUID
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

  -- Build complete invoice data
  SELECT json_build_object(
    'store_info', (
      SELECT row_to_json(sbi.*)
      FROM public.store_business_info sbi
      WHERE sbi.store_id = v_store_id
      LIMIT 1
    ),
    'transaction', (
      SELECT row_to_json(t.*)
      FROM public.transactions t
      WHERE t.id = p_transaction_id
        AND t.store_id = v_store_id
      LIMIT 1
    ),
    'customer', (
      SELECT row_to_json(c.*)
      FROM public.transactions t
      LEFT JOIN public.customers c ON t.customer_id = c.id
      WHERE t.id = p_transaction_id
        AND t.store_id = v_store_id
      LIMIT 1
    ),
    'items', (
      SELECT json_agg(
        json_build_object(
          'id', ti.id,
          'product_id', ti.product_id,
          'product_name', p.name,
          'product_sku', p.sku,
          'quantity', ti.quantity,
          'unit_name', ti.unit_name,
          'unit_conversion_factor', ti.unit_conversion_factor,
          'base_unit_quantity', ti.base_unit_quantity,
          'price_at_sale', ti.price_at_sale,
          'sub_total', ti.sub_total,
          'discount_amount', ti.discount_amount
        )
      )
      FROM public.transaction_items ti
      LEFT JOIN public.products p ON ti.product_id = p.id
      WHERE ti.transaction_id = p_transaction_id
        AND ti.store_id = v_store_id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_invoice_data(UUID) TO authenticated;

-- Comment
COMMENT ON FUNCTION public.get_invoice_data(UUID) IS
  'Get complete invoice data for a transaction (store info, transaction, customer, items)';
