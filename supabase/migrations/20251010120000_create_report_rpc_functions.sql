
-- supabase/migrations/YYYYMMDDHHMMSS_create_report_rpc_functions.sql

-- =============================================================================
-- 1. GET REVENUE SUMMARY
-- Description: Returns key revenue metrics for a given date range.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_revenue_summary(start_date date, end_date date)
RETURNS TABLE (
    total_revenue numeric,
    total_profit numeric,
    total_transactions bigint,
    cash_revenue numeric,
    debt_revenue numeric
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
    WITH period_transactions AS (
        SELECT t.id, t.total_amount, t.payment_method
        FROM transactions t
        WHERE t.store_id = current_user_store_id
          AND t.transaction_date >= start_date
          AND t.transaction_date <= end_date
    ),
    period_costs AS (
        SELECT
            ti.transaction_id,
            SUM(ti.quantity * pb.cost_price) as total_cost
        FROM transaction_items ti
        JOIN product_batches pb ON ti.batch_id = pb.id
        WHERE ti.transaction_id IN (SELECT id FROM period_transactions)
          AND ti.store_id = current_user_store_id
        GROUP BY ti.transaction_id
    )
    SELECT
        COALESCE(SUM(pt.total_amount), 0) AS total_revenue,
        COALESCE(SUM(pt.total_amount), 0) - COALESCE(SUM(pc.total_cost), 0) AS total_profit,
        COUNT(DISTINCT pt.id) AS total_transactions,
        COALESCE(SUM(CASE WHEN pt.payment_method = 'cash' THEN pt.total_amount ELSE 0 END), 0) AS cash_revenue,
        COALESCE(SUM(CASE WHEN pt.payment_method = 'debt' THEN pt.total_amount ELSE 0 END), 0) AS debt_revenue
    FROM period_transactions pt
    LEFT JOIN period_costs pc ON pt.id = pc.transaction_id;
END;
$$;

-- =============================================================================
-- 2. GET REVENUE TREND
-- Description: Returns time-series data for revenue charts.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_revenue_trend(p_start_date date, p_end_date date, p_interval text DEFAULT 'day')
RETURNS TABLE (
    trend_date date,
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
        ds.day as trend_date,
        COALESCE(dr.revenue, 0) as revenue,
        COALESCE(dr.transaction_count, 0) as transaction_count
    FROM date_series ds
    LEFT JOIN daily_revenue dr ON ds.day = dr.trend_date
    ORDER BY ds.day;
END;
$$;

-- =============================================================================
-- 3. GET TOP PERFORMING PRODUCTS
-- Description: Returns top products by revenue or profit.
-- =============================================================================
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
        SUM(ti.quantity) as total_quantity,
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

-- =============================================================================
-- 4. GET INVENTORY SUMMARY
-- Description: Returns key metrics for current inventory.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_inventory_summary()
RETURNS TABLE (
    total_inventory_value numeric,
    total_selling_value numeric,
    potential_profit numeric,
    profit_margin numeric,
    total_items bigint,
    total_batches bigint
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
        COALESCE(SUM(pb.quantity * pb.cost_price), 0) as total_inventory_value,
        COALESCE(SUM(pb.quantity * p.current_selling_price), 0) as total_selling_value,
        COALESCE(SUM(pb.quantity * (p.current_selling_price - pb.cost_price)), 0) as potential_profit,
        CASE
            WHEN SUM(pb.quantity * p.current_selling_price) > 0
            THEN (SUM(pb.quantity * (p.current_selling_price - pb.cost_price)) / SUM(pb.quantity * p.current_selling_price)) * 100
            ELSE 0
        END as profit_margin,
        COALESCE(SUM(pb.quantity), 0) as total_items,
        COUNT(pb.id) as total_batches
    FROM product_batches pb
    JOIN products p ON pb.product_id = p.id
    WHERE pb.store_id = current_user_store_id
      AND pb.is_available = true
      AND pb.quantity > 0;
END;
$$;

-- =============================================================================
-- 5. GET INVENTORY ALERTS
-- Description: Returns lists of products that are low-stock or expiring soon.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_inventory_alerts(p_low_stock_threshold int DEFAULT 10, p_expiring_soon_days int DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_store_id uuid;
    low_stock_products jsonb;
    expiring_soon_products jsonb;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Get low stock products
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO low_stock_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            SUM(pb.quantity) as current_stock,
            p.min_stock_level
        FROM product_batches pb
        JOIN products p ON pb.product_id = p.id
        WHERE pb.store_id = current_user_store_id
          AND p.store_id = current_user_store_id
          AND pb.is_available = true
        GROUP BY p.id, p.name, p.sku, p.min_stock_level
        HAVING SUM(pb.quantity) <= p.min_stock_level
           AND SUM(pb.quantity) <= p_low_stock_threshold
    ) t;

    -- Get expiring soon products
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO expiring_soon_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            pb.id as batch_id,
            pb.batch_number,
            pb.quantity,
            pb.expiry_date,
            EXTRACT(DAY FROM (pb.expiry_date - NOW())) as days_until_expiry
        FROM product_batches pb
        JOIN products p ON pb.product_id = p.id
        WHERE pb.store_id = current_user_store_id
          AND p.store_id = current_user_store_id
          AND pb.is_available = true
          AND pb.quantity > 0
          AND pb.expiry_date IS NOT NULL
          AND pb.expiry_date <= NOW() + (p_expiring_soon_days || ' days')::interval
        ORDER BY pb.expiry_date ASC
    ) t;

    RETURN jsonb_build_object(
        'low_stock_products', low_stock_products,
        'expiring_soon_products', expiring_soon_products
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_revenue_summary(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION get_revenue_trend(date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_top_performing_products(date, date, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION get_inventory_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION get_inventory_alerts(int, int) TO authenticated;
