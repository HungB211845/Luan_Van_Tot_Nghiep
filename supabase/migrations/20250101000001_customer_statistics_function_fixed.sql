-- Fixed Customer Statistics Function
-- This function provides transaction count, total revenue, and outstanding debt for a customer

DROP FUNCTION IF EXISTS get_customer_statistics(UUID, UUID);

CREATE OR REPLACE FUNCTION get_customer_statistics(
    p_customer_id UUID,
    p_store_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
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
            COUNT(*)::INTEGER as transaction_count,
            COALESCE(SUM(total_amount), 0)::DECIMAL as total_revenue,
            COALESCE(SUM(CASE WHEN is_debt THEN debt_amount ELSE 0 END), 0)::DECIMAL as outstanding_debt
        FROM customer_transactions
    )
    SELECT json_build_object(
        'transaction_count', transaction_count,
        'total_revenue', total_revenue,
        'outstanding_debt', outstanding_debt
    ) INTO result
    FROM stats;

    RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_customer_statistics(UUID, UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_customer_statistics(UUID, UUID) IS
'Returns transaction statistics for a customer as JSON object with transaction_count, total_revenue, and outstanding_debt';