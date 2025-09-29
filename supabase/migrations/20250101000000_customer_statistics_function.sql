-- Customer Statistics Function
-- This function provides transaction count, total revenue, and outstanding debt for a customer

CREATE OR REPLACE FUNCTION get_customer_statistics(
    p_customer_id UUID,
    p_store_id UUID
)
RETURNS TABLE (
    transaction_count INTEGER,
    total_revenue DECIMAL,
    outstanding_debt DECIMAL
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH customer_transactions AS (
        SELECT
            t.total_amount,
            t.is_debt,
            COALESCE(d.outstanding_amount, 0) as debt_amount
        FROM transactions t
        LEFT JOIN debts d ON t.id = d.transaction_id AND d.store_id = p_store_id
        WHERE t.customer_id = p_customer_id
        AND t.store_id = p_store_id
    ),
    stats AS (
        SELECT
            COUNT(*) as trans_count,
            COALESCE(SUM(total_amount), 0) as total_rev,
            COALESCE(SUM(CASE WHEN is_debt THEN debt_amount ELSE 0 END), 0) as outstanding_debt_sum
        FROM customer_transactions
    )
    SELECT
        trans_count::INTEGER,
        total_rev::DECIMAL,
        outstanding_debt_sum::DECIMAL
    FROM stats;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_customer_statistics(UUID, UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_customer_statistics(UUID, UUID) IS
'Returns transaction statistics for a customer including transaction count, total revenue, and outstanding debt';