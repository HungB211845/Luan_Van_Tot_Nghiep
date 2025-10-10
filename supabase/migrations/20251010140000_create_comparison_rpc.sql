-- Corrected version of the RPC function to prevent revenue inflation.
-- Logic now separates revenue calculation from cost calculation to avoid fan-out issues from joins.

DROP FUNCTION IF EXISTS get_revenue_summary_with_comparison(date, date);

CREATE OR REPLACE FUNCTION get_revenue_summary_with_comparison(p_start_date date, p_end_date date)
RETURNS TABLE (
    current_total_revenue numeric,
    current_total_profit numeric,
    current_total_transactions bigint,
    previous_total_revenue numeric,
    previous_total_profit numeric,
    previous_total_transactions bigint,
    revenue_change_percentage numeric,
    profit_change_percentage numeric,
    transactions_change_percentage numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_store_id uuid;
    v_previous_start_date date;
    v_previous_end_date date;
    v_duration int;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Calculate previous period
    v_duration := p_end_date - p_start_date;
    v_previous_end_date := p_start_date - interval '1 day';
    v_previous_start_date := v_previous_end_date - (v_duration || ' days')::interval;

    RETURN QUERY
    WITH 
    -- CTE 1: Calculate revenue and transaction counts directly from the transactions table.
    -- This is the correct way to do it, avoiding the join that causes fan-out.
    revenue_summary AS (
        SELECT
            COALESCE(SUM(CASE WHEN t.transaction_date BETWEEN p_start_date AND p_end_date THEN t.total_amount ELSE 0 END), 0) as current_revenue,
            COALESCE(SUM(CASE WHEN t.transaction_date BETWEEN v_previous_start_date AND v_previous_end_date THEN t.total_amount ELSE 0 END), 0) as previous_revenue,
            COUNT(DISTINCT CASE WHEN t.transaction_date BETWEEN p_start_date AND p_end_date THEN t.id END) as current_transactions,
            COUNT(DISTINCT CASE WHEN t.transaction_date BETWEEN v_previous_start_date AND v_previous_end_date THEN t.id END) as previous_transactions
        FROM transactions t
        WHERE t.store_id = current_user_store_id
          AND t.transaction_date BETWEEN v_previous_start_date AND p_end_date
    ),
    -- CTE 2: Calculate costs by joining through transaction_items.
    cost_summary AS (
        SELECT
            COALESCE(SUM(CASE WHEN t.transaction_date BETWEEN p_start_date AND p_end_date THEN (ti.quantity * pb.cost_price) ELSE 0 END), 0) as current_cost,
            COALESCE(SUM(CASE WHEN t.transaction_date BETWEEN v_previous_start_date AND v_previous_end_date THEN (ti.quantity * pb.cost_price) ELSE 0 END), 0) as previous_cost
        FROM transactions t
        JOIN transaction_items ti ON t.id = ti.transaction_id
        JOIN product_batches pb ON ti.batch_id = pb.id
        WHERE t.store_id = current_user_store_id
          AND t.transaction_date BETWEEN v_previous_start_date AND p_end_date
    )
    -- Final SELECT: Combine the correct, non-inflated numbers.
    SELECT
        rs.current_revenue as current_total_revenue,
        (rs.current_revenue - cs.current_cost) as current_total_profit,
        rs.current_transactions as current_total_transactions,
        rs.previous_revenue as previous_total_revenue,
        (rs.previous_revenue - cs.previous_cost) as previous_total_profit,
        rs.previous_transactions as previous_total_transactions,
        -- Revenue Change Percentage
        CASE 
            WHEN rs.previous_revenue = 0 THEN NULL 
            ELSE ((rs.current_revenue - rs.previous_revenue) / rs.previous_revenue) * 100 
        END as revenue_change_percentage,
        -- Profit Change Percentage
        CASE 
            WHEN (rs.previous_revenue - cs.previous_cost) = 0 THEN NULL 
            ELSE (((rs.current_revenue - cs.current_cost) - (rs.previous_revenue - cs.previous_cost)) / (rs.previous_revenue - cs.previous_cost)) * 100 
        END as profit_change_percentage,
        -- Transactions Change Percentage
        CASE 
            WHEN rs.previous_transactions = 0 THEN NULL 
            ELSE ((rs.current_transactions::numeric - rs.previous_transactions::numeric) / rs.previous_transactions::numeric) * 100 
        END as transactions_change_percentage
    FROM revenue_summary rs, cost_summary cs;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_revenue_summary_with_comparison(date, date) TO authenticated;