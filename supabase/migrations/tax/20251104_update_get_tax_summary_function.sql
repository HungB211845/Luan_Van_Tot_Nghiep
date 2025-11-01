-- Migration: Update get_tax_summary to use store-specific revenue tax rate

CREATE OR REPLACE FUNCTION get_tax_summary(
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_store_id UUID;
  v_total_revenue NUMERIC DEFAULT 0;
  v_total_expenses NUMERIC DEFAULT 0;
  v_transaction_count INTEGER DEFAULT 0;
  v_revenue_tax_rate NUMERIC(5,2) DEFAULT 1.5;
  v_result JSON;
BEGIN
  v_store_id := COALESCE(
    (current_setting('request.jwt.claims', true)::json->'app_metadata'->>'store_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->>'store_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->'user_metadata'->>'store_id')::uuid,
    auth.uid()
  );

  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated and have a valid store_id';
  END IF;

  -- Fetch configured revenue tax rate (default 1.5%)
  SELECT COALESCE(revenue_tax_rate, 1.5)
    INTO v_revenue_tax_rate
  FROM public.store_business_info
  WHERE store_id = v_store_id
  LIMIT 1;

  SELECT
    COALESCE(SUM(total_amount), 0),
    COUNT(*)
  INTO v_total_revenue, v_transaction_count
  FROM transactions
  WHERE store_id = v_store_id
    AND created_at BETWEEN p_start_date AND p_end_date;

  SELECT COALESCE(SUM(total_amount), 0)
  INTO v_total_expenses
  FROM purchase_orders
  WHERE store_id = v_store_id
    AND status = 'DELIVERED'
    AND delivery_date BETWEEN p_start_date AND p_end_date;

  v_result := json_build_object(
    'total_revenue', v_total_revenue,
    'estimated_tax', ROUND(v_total_revenue * (v_revenue_tax_rate / 100), 2),
    'total_expenses', v_total_expenses,
    'total_transactions', v_transaction_count,
    'tax_rate', v_revenue_tax_rate
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION get_tax_summary IS
  'Calculates tax summary using store-specific revenue tax rate configuration.';

GRANT EXECUTE ON FUNCTION get_tax_summary(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
