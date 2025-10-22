-- RPC Function: Get transactions for Excel export (with VAT and metadata)
-- Usage: SELECT * FROM get_transactions_for_export('2025-10-01', '2025-10-31');
-- Updated: 2025-10-22 - Added transaction metadata, VAT fields per NĐ 123/2020

CREATE OR REPLACE FUNCTION public.get_transactions_for_export(
  p_start_date DATE,
  p_end_date DATE
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

  -- Build transactions array with items and VAT metadata
  SELECT json_agg(entry.transaction_json ORDER BY entry.transaction_date DESC)
  INTO v_result
  FROM (
    SELECT
      t.transaction_date,
      json_build_object(
        'transaction', json_build_object(
          'id', t.id,
          'transaction_date', t.transaction_date,
          'invoice_number', t.invoice_number,
          'payment_method', t.payment_method,
          'total_amount', t.total_amount,
          'surcharge_amount', t.surcharge_amount,
          'notes', t.notes,
          'created_at', t.created_at
        ),
        'customer_name', COALESCE(c.name, 'Khách lẻ'),
        'items', (
          SELECT json_agg(
            json_build_object(
              'product_name', COALESCE(p.name, 'Unknown Product'),
              'product_sku', p.sku,
              'quantity', ti.quantity,
              'unit_name', ti.unit_name,
              'price_at_sale', ti.price_at_sale,
              'sub_total', ti.sub_total,
              'discount_amount', ti.discount_amount,
              -- VAT fields
              'tax_rate', v_default_vat_rate,
              'tax_amount', ROUND((ti.sub_total * v_default_vat_rate / 100)::numeric, 0),
              'gross_amount', ti.sub_total + ROUND((ti.sub_total * v_default_vat_rate / 100)::numeric, 0)
            )
            ORDER BY ti.created_at
          )
          FROM public.transaction_items ti
          LEFT JOIN public.products p ON ti.product_id = p.id
          WHERE ti.transaction_id = t.id
            AND ti.store_id = v_store_id
        )
      ) AS transaction_json
    FROM public.transactions t
    LEFT JOIN public.customers c ON t.customer_id = c.id
    WHERE t.store_id = v_store_id
      AND t.transaction_date >= p_start_date
      AND t.transaction_date < (p_end_date + INTERVAL '1 day')
  ) AS entry;

  RETURN COALESCE(v_result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_transactions_for_export(DATE, DATE) TO authenticated;

-- Comment
COMMENT ON FUNCTION public.get_transactions_for_export(DATE, DATE) IS
  'Get all transactions with items for Excel export within date range';
