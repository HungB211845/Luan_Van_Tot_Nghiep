-- RPC Function: Get complete invoice data for a transaction (with VAT support)
-- Usage: SELECT * FROM get_invoice_data('transaction-uuid');
-- Updated: 2025-10-22 - Added VAT fields per NĐ 123/2020, TT 32/2025

CREATE OR REPLACE FUNCTION public.get_invoice_data(
  p_transaction_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
  v_store_id UUID;
  v_default_vat_rate NUMERIC(5,2);
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

  -- Build complete invoice data with VAT calculations
  SELECT json_build_object(
    'store_info', (
      SELECT row_to_json(sbi.*)
      FROM public.store_business_info sbi
      WHERE sbi.store_id = v_store_id
      LIMIT 1
    ),
    'transaction', (
      SELECT json_build_object(
        'id', t.id,
        'store_id', t.store_id,
        'customer_id', t.customer_id,
        'total_amount', t.total_amount,
        'surcharge_amount', t.surcharge_amount,
        'transaction_date', t.transaction_date,
        'is_debt', t.is_debt,
        'payment_method', UPPER(t.payment_method),  -- Convert to uppercase for PaymentMethod enum
        'notes', t.notes,
        'invoice_number', t.invoice_number,
        'created_by', t.created_by,
        'created_at', t.created_at
      )
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
          'discount_amount', ti.discount_amount,
          -- VAT fields (using store default rate, can be overridden by product-specific rate in future)
          'tax_rate', v_default_vat_rate,
          'tax_amount', ROUND((ti.sub_total * v_default_vat_rate / 100)::numeric, 0),
          'gross_amount', ti.sub_total + ROUND((ti.sub_total * v_default_vat_rate / 100)::numeric, 0)
        )
      )
      FROM public.transaction_items ti
      LEFT JOIN public.products p ON ti.product_id = p.id
      WHERE ti.transaction_id = p_transaction_id
        AND ti.store_id = v_store_id
    ),
    'vat_total', (
      SELECT COALESCE(SUM(ROUND((ti.sub_total * v_default_vat_rate / 100)::numeric, 0)), 0)
      FROM public.transaction_items ti
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
