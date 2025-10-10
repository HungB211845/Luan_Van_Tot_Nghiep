-- supabase/migrations/20251010130000_fix_report_rpc_types.sql

-- =============================================================================
-- 1. FIX GET REVENUE TREND
-- Description: Drops the old function and recreates it with the correct output column name 'date'.
-- =============================================================================
DROP FUNCTION IF EXISTS get_revenue_trend(date, date, text);
CREATE OR REPLACE FUNCTION get_revenue_trend(p_start_date date, p_end_date date, p_interval text DEFAULT 'day')
RETURNS TABLE (
    date date, -- Changed from trend_date
    revenue numeric,
    transaction_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_store_id uuid;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    RETURN QUERY
    WITH date_series AS (
        SELECT generate_series(p_start_date, p_end_date, '1 day'::interval)::date as day
    ),
    daily_revenue AS (
        SELECT
            DATE_TRUNC(p_interval, t.transaction_date)::date as trend_date,
            SUM(t.total_amount) as revenue,
            COUNT(t.id) as transaction_count
        FROM transactions t
        WHERE t.store_id = current_user_store_id
          AND t.transaction_date >= p_start_date
          AND t.transaction_date <= p_end_date
        GROUP BY 1
    )
    SELECT
        ds.day as date, -- FIX: Changed alias to 'date'
        COALESCE(dr.revenue, 0) as revenue,
        COALESCE(dr.transaction_count, 0) as transaction_count
    FROM date_series ds
    LEFT JOIN daily_revenue dr ON ds.day = dr.trend_date
    ORDER BY ds.day;
END;
$$;

-- =============================================================================
-- 2. FIX GET TOP PERFORMING PRODUCTS
-- Description: Drops the old function and recreates it, casting SUM(quantity) to numeric.
-- =============================================================================
DROP FUNCTION IF EXISTS get_top_performing_products(date, date, text, int);
CREATE OR REPLACE FUNCTION get_top_performing_products(p_start_date date, p_end_date date, p_order_by text DEFAULT 'revenue', p_limit int DEFAULT 10)
RETURNS TABLE (
    product_id uuid,
    product_name text,
    total_quantity numeric,
    total_revenue numeric,
    total_profit numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_store_id uuid;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    RETURN QUERY
    SELECT
        p.id as product_id,
        p.name as product_name,
        SUM(ti.quantity)::numeric as total_quantity, -- FIX: Cast to numeric
        SUM(ti.sub_total) as total_revenue,
        SUM(ti.sub_total - (ti.quantity * pb.cost_price)) as total_profit
    FROM transaction_items ti
    JOIN products p ON ti.product_id = p.id
    JOIN product_batches pb ON ti.batch_id = pb.id
    WHERE ti.store_id = current_user_store_id
      AND ti.created_at >= p_start_date
      AND ti.created_at <= p_end_date
    GROUP BY p.id, p.name
    ORDER BY
        CASE WHEN p_order_by = 'profit' THEN SUM(ti.sub_total - (ti.quantity * pb.cost_price)) ELSE SUM(ti.sub_total) END DESC
    LIMIT p_limit;
END;
$$;

-- Grant permissions again for the modified functions
GRANT EXECUTE ON FUNCTION get_revenue_trend(date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_top_performing_products(date, date, text, int) TO authenticated;