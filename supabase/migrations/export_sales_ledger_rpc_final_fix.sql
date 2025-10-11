-- =============================================================================
-- FINAL CORRECT EXPORT SALES LEDGER RPC FUNCTION
-- =============================================================================
-- Fixed all column names based on actual database schema
-- =============================================================================

CREATE OR REPLACE FUNCTION export_sales_ledger(
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
  "Số TT" INTEGER,
  "Ngày bán" TEXT,
  "Số hóa đơn" TEXT,
  "Tên khách hàng" TEXT,
  "Tên sản phẩm" TEXT,
  "Đơn vị tính" TEXT,
  "Số lượng" NUMERIC,
  "Đơn giá" NUMERIC,
  "Thành tiền" NUMERIC,
  "Tổng hóa đơn" NUMERIC,
  "Ghi chú" TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_store_id UUID;
BEGIN
  -- Get current user's store_id from JWT claims or user metadata
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

  -- Return detailed sales ledger data with CORRECT column names
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY t.created_at, ti.id)::INTEGER AS "Số TT",
    TO_CHAR(t.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY') AS "Ngày bán",
    CONCAT('HD-', LPAD(t.id::text, 6, '0')) AS "Số hóa đơn",
    COALESCE(c.name, 'Khách lẻ') AS "Tên khách hàng",
    p.name AS "Tên sản phẩm",
    -- FIXED: Use attributes JSON for unit with category fallbacks
    COALESCE(
      p.attributes->>'unit',
      CASE p.category
        WHEN 'FERTILIZER' THEN 'Bao'
        WHEN 'PESTICIDE' THEN 'Chai'
        WHEN 'SEED' THEN 'Kg'
        ELSE 'Cái'
      END
    ) AS "Đơn vị tính",
    -- FIX: Cast INTEGER to NUMERIC for type compatibility
    ti.quantity::NUMERIC AS "Số lượng",
    -- FIXED: Use price_at_sale (NOT unit_price), ensure NUMERIC
    ti.price_at_sale::NUMERIC AS "Đơn giá",
    -- FIXED: Use sub_total OR calculate, ensure NUMERIC type
    COALESCE(ti.sub_total, (ti.quantity * ti.price_at_sale))::NUMERIC AS "Thành tiền",
    t.total_amount::NUMERIC AS "Tổng hóa đơn",
    COALESCE(t.notes, '') AS "Ghi chú"
  FROM transactions t
  LEFT JOIN customers c ON t.customer_id = c.id
  INNER JOIN transaction_items ti ON t.id = ti.transaction_id
  INNER JOIN products p ON ti.product_id = p.id
  WHERE t.store_id = v_store_id
    AND t.created_at BETWEEN p_start_date AND p_end_date
  ORDER BY t.created_at ASC, ti.id ASC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION export_sales_ledger(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- Add function comment
COMMENT ON FUNCTION export_sales_ledger IS 'TYPE-FIXED: All numeric columns cast to NUMERIC type for proper CSV export compatibility';

-- =============================================================================
-- END OF FINAL CORRECT EXPORT SALES LEDGER RPC FUNCTION
-- =============================================================================