-- RPC Function: Get transactions for Excel export
-- Usage: SELECT * FROM get_transactions_for_export('2025-10-01', '2025-10-31');

CREATE OR REPLACE FUNCTION public.get_transactions_for_export(
  p_start_date DATE,
  p_end_date DATE
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

  -- Build transactions array with items
  SELECT json_agg(
    json_build_object(
      'transaction', row_to_json(t.*),
      'customer_name', c.name,
      'items', (
        SELECT json_agg(
          json_build_object(
            'product_name', p.name,
            'product_sku', p.sku,
            'quantity', ti.quantity,
            'unit_name', ti.unit_name,
            'price_at_sale', ti.price_at_sale,
            'sub_total', ti.sub_total,
            'discount_amount', ti.discount_amount
          )
        )
        FROM public.transaction_items ti
        LEFT JOIN public.products p ON ti.product_id = p.id
        WHERE ti.transaction_id = t.id
          AND ti.store_id = v_store_id
      )
    )
  ) INTO v_result
  FROM public.transactions t
  LEFT JOIN public.customers c ON t.customer_id = c.id
  WHERE t.store_id = v_store_id
    AND t.transaction_date >= p_start_date
    AND t.transaction_date < (p_end_date + INTERVAL '1 day')
  ORDER BY t.transaction_date DESC;

  RETURN COALESCE(v_result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_transactions_for_export(DATE, DATE) TO authenticated;

-- Comment
COMMENT ON FUNCTION public.get_transactions_for_export(DATE, DATE) IS
  'Get all transactions with items for Excel export within date range';
