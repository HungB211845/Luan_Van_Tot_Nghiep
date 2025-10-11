-- =============================================================================
-- FIXED EXPORT SALES LEDGER RPC FUNCTION
-- =============================================================================
-- Fix for p.unit column not found - use attributes JSON or fallback
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

  -- Return detailed sales ledger data with transaction items
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY t.created_at, ti.id)::INTEGER AS "Số TT",
    TO_CHAR(t.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY') AS "Ngày bán",
    CONCAT('HD-', LPAD(t.id::text, 6, '0')) AS "Số hóa đôn",
    COALESCE(c.name, 'Khách lẻ') AS "Tên khách hàng",
    p.name AS "Tên sản phẩm",
    -- Fix: Use attributes JSON to get unit, fallback to default
    COALESCE(
      p.attributes->>'unit',
      CASE p.category
        WHEN 'FERTILIZER' THEN 'Bao'
        WHEN 'PESTICIDE' THEN 'Chai'
        WHEN 'SEED' THEN 'Kg'
        ELSE 'Cái'
      END
    ) AS "Đơn vị tính",
    ti.quantity AS "Số lượng",
    ti.unit_price AS "Đơn giá",
    (ti.quantity * ti.unit_price) AS "Thành tiền",
    t.total_amount AS "Tổng hóa đơn",
    CASE 
      WHEN t.notes IS NOT NULL AND t.notes != '' THEN t.notes
      ELSE ''
    END AS "Ghi chú"
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
COMMENT ON FUNCTION export_sales_ledger IS 'FIXED: Exports detailed sales ledger for tax reporting. Uses attributes JSON for unit info with category-based fallbacks.';

-- =============================================================================
-- END OF FIXED EXPORT SALES LEDGER RPC FUNCTION
-- =============================================================================