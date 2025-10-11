-- =============================================================================
-- TAX RPC FUNCTIONS FOR AGRICULTURAL POS
-- =============================================================================
-- This migration creates RPC functions for the Tax module to calculate
-- tax obligations and generate sales ledgers for tax reporting.
-- =============================================================================

-- Function 1: Get Tax Summary
-- =============================================================================
-- Calculates total revenue, estimated tax (1.5%), and total expenses for a date range
-- Returns: JSON object with tax summary data
-- =============================================================================

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
  v_result JSON;
BEGIN
  -- Get current user's store_id from JWT claims (app_metadata OR user_metadata)
  -- First try app_metadata, then user_metadata as fallback
  v_store_id := COALESCE(
    (current_setting('request.jwt.claims', true)::json->'app_metadata'->>'store_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->>'store_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->'user_metadata'->>'store_id')::uuid,
    auth.uid()
  );

  -- Validate store_id
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated and have a valid store_id';
  END IF;

  -- Calculate total revenue from transactions
  SELECT
    COALESCE(SUM(total_amount), 0),
    COUNT(*)
  INTO v_total_revenue, v_transaction_count
  FROM transactions
  WHERE store_id = v_store_id
    AND created_at BETWEEN p_start_date AND p_end_date;

  -- Calculate total expenses from purchase_orders (DELIVERED status only)
  SELECT COALESCE(SUM(total_amount), 0)
  INTO v_total_expenses
  FROM purchase_orders
  WHERE store_id = v_store_id
    AND status = 'DELIVERED'
    AND delivery_date BETWEEN p_start_date AND p_end_date;

  -- Build result JSON
  v_result := json_build_object(
    'total_revenue', v_total_revenue,
    'estimated_tax', ROUND(v_total_revenue * 0.015, 2), -- 1.5% tax rate
    'total_expenses', v_total_expenses,
    'total_transactions', v_transaction_count
  );

  RETURN v_result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_tax_summary(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- Add function comment
COMMENT ON FUNCTION get_tax_summary IS 'Calculates tax summary including revenue, expenses, and estimated tax (1.5% of revenue) for a given date range';


-- Function 2: Get Sales Ledger for Export
-- =============================================================================
-- Returns detailed list of all transactions for a date range
-- Used to generate export files (CSV/Excel) for tax reporting
-- Returns: TABLE with transaction details
-- =============================================================================

CREATE OR REPLACE FUNCTION get_sales_ledger_for_export(
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
  transaction_id UUID,
  transaction_date TIMESTAMPTZ,
  customer_name TEXT,
  total_amount NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_store_id UUID;
BEGIN
  -- Get current user's store_id from JWT claims (app_metadata OR user_metadata)
  -- First try app_metadata, then user_metadata as fallback
  v_store_id := COALESCE(
    (current_setting('request.jwt.claims', true)::json->'app_metadata'->>'store_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->>'store_id')::uuid,
    (current_setting('request.jwt.claims', true)::json->'user_metadata'->>'store_id')::uuid,
    auth.uid()
  );

  -- Validate store_id
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'User must be authenticated and have a valid store_id';
  END IF;

  -- Return sales ledger data
  RETURN QUERY
  SELECT
    t.id AS transaction_id,
    t.created_at AS transaction_date,
    COALESCE(c.name, 'Khách lẻ') AS customer_name,
    t.total_amount
  FROM transactions t
  LEFT JOIN customers c ON t.customer_id = c.id
  WHERE t.store_id = v_store_id
    AND t.created_at BETWEEN p_start_date AND p_end_date
  ORDER BY t.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_sales_ledger_for_export(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- Add function comment
COMMENT ON FUNCTION get_sales_ledger_for_export IS 'Returns detailed sales ledger for tax reporting and export. Includes transaction ID, date, customer name, and amount';

-- =============================================================================
-- END OF TAX RPC FUNCTIONS MIGRATION
-- =============================================================================
