-- =============================================================================
-- FIX: Update get_customer_statistics to show REMAINING debt instead of TOTAL debt
-- Migration created: 2025-10-01
-- =============================================================================

-- The current function incorrectly shows total debt from transactions (is_debt flag)
-- This migration fixes it to show actual remaining debt from debts table

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
    v_transaction_count INTEGER;
    v_total_revenue DECIMAL;
    v_outstanding_debt DECIMAL;
    result JSON;
BEGIN
    -- Get transaction count and total revenue
    SELECT
        COUNT(*)::INTEGER,
        COALESCE(SUM(total_amount), 0)::DECIMAL
    INTO
        v_transaction_count,
        v_total_revenue
    FROM transactions
    WHERE customer_id = p_customer_id
    AND store_id = p_store_id;

    -- Get outstanding debt (remaining amount from debts table)
    SELECT
        COALESCE(SUM(remaining_amount), 0)::DECIMAL
    INTO
        v_outstanding_debt
    FROM debts
    WHERE customer_id = p_customer_id
    AND store_id = p_store_id
    AND status IN ('pending', 'partial', 'overdue');

    -- Build result JSON
    result := json_build_object(
        'transaction_count', v_transaction_count,
        'total_revenue', v_total_revenue,
        'outstanding_debt', v_outstanding_debt
    );

    RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_customer_statistics(UUID, UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_customer_statistics(UUID, UUID) IS
'Returns transaction statistics for a customer as JSON object with transaction_count, total_revenue, and outstanding_debt (actual remaining debt from debts table)';

-- Verification
DO $$
BEGIN
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'CUSTOMER STATISTICS FIX - MIGRATION COMPLETE';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'Function get_customer_statistics updated';
    RAISE NOTICE 'Now shows REMAINING debt instead of TOTAL debt';
    RAISE NOTICE '==============================================';
END $$;
