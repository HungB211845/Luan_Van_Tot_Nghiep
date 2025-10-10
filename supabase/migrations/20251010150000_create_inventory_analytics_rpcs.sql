-- =============================================================================
-- MIGRATION: Inventory Analytics Dashboard RPCs
-- Description: Updates get_inventory_alerts to include slow-moving products
--              and creates new RPC for inventory analytics lists
-- Date: 2025-10-10
-- =============================================================================

-- =============================================================================
-- 1. UPDATE: get_inventory_alerts - Add slow_moving_products
-- =============================================================================
DROP FUNCTION IF EXISTS get_inventory_alerts(int, int);

CREATE OR REPLACE FUNCTION get_inventory_alerts(p_low_stock_threshold int DEFAULT 10, p_expiring_soon_days int DEFAULT 30, p_slow_moving_days int DEFAULT 90)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_store_id uuid;
    low_stock_products jsonb;
    expiring_soon_products jsonb;
    slow_moving_products jsonb;
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

    -- Get slow-moving products (no sales in last X days but have stock)
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO slow_moving_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            SUM(pb.quantity) as current_stock,
            COALESCE(MAX(ti.created_at), pb.created_at) as last_sale_date,
            EXTRACT(DAY FROM (NOW() - COALESCE(MAX(ti.created_at), pb.created_at))) as days_since_last_sale
        FROM products p
        JOIN product_batches pb ON p.id = pb.product_id
        LEFT JOIN transaction_items ti ON p.id = ti.product_id
            AND ti.created_at >= NOW() - (p_slow_moving_days || ' days')::interval
            AND ti.store_id = current_user_store_id
        WHERE p.store_id = current_user_store_id
          AND pb.store_id = current_user_store_id
          AND pb.is_available = true
          AND p.is_active = true
        GROUP BY p.id, p.name, p.sku, pb.created_at
        HAVING SUM(pb.quantity) > 0
           AND COUNT(ti.id) = 0  -- No sales in specified period
        ORDER BY MAX(COALESCE(ti.created_at, pb.created_at)) ASC NULLS FIRST
        LIMIT 50
    ) t;

    RETURN jsonb_build_object(
        'low_stock_products', low_stock_products,
        'expiring_soon_products', expiring_soon_products,
        'slow_moving_products', slow_moving_products
    );
END;
$$;

-- =============================================================================
-- 2. CREATE: get_inventory_analytics_lists - Top/Bottom Product Lists
-- =============================================================================
CREATE OR REPLACE FUNCTION get_inventory_analytics_lists()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_store_id uuid;
    top_value_products jsonb;
    fast_turnover_products jsonb;
    slow_turnover_products jsonb;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Top 5 products by inventory value (quantity * cost_price)
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO top_value_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            SUM(pb.quantity * pb.cost_price) as inventory_value,
            SUM(pb.quantity) as current_stock
        FROM product_batches pb
        JOIN products p ON pb.product_id = p.id
        WHERE pb.store_id = current_user_store_id
          AND p.store_id = current_user_store_id
          AND pb.is_available = true
          AND pb.quantity > 0
        GROUP BY p.id, p.name, p.sku
        ORDER BY inventory_value DESC
        LIMIT 5
    ) t;

    -- Top 5 products by turnover ratio (sales / average stock) in last 30 days
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO fast_turnover_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            SUM(ti.quantity) as total_sold,
            AVG(pb.quantity) as avg_stock,
            CASE
                WHEN AVG(pb.quantity) > 0 THEN SUM(ti.quantity) / AVG(pb.quantity)
                ELSE 0
            END as turnover_ratio
        FROM products p
        JOIN product_batches pb ON p.id = pb.product_id
        LEFT JOIN transaction_items ti ON p.id = ti.product_id
            AND ti.created_at >= NOW() - interval '30 days'
            AND ti.store_id = current_user_store_id
        WHERE p.store_id = current_user_store_id
          AND pb.store_id = current_user_store_id
          AND pb.is_available = true
          AND p.is_active = true
        GROUP BY p.id, p.name, p.sku
        HAVING SUM(ti.quantity) > 0  -- Must have sales
           AND AVG(pb.quantity) > 0  -- Must have stock
        ORDER BY turnover_ratio DESC
        LIMIT 5
    ) t;

    -- Bottom 5 products by turnover ratio (slowest movers with stock)
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO slow_turnover_products
    FROM (
        SELECT
            p.id as product_id,
            p.name as product_name,
            p.sku,
            COALESCE(SUM(ti.quantity), 0) as total_sold,
            AVG(pb.quantity) as avg_stock,
            CASE
                WHEN AVG(pb.quantity) > 0 THEN COALESCE(SUM(ti.quantity), 0) / AVG(pb.quantity)
                ELSE 0
            END as turnover_ratio
        FROM products p
        JOIN product_batches pb ON p.id = pb.product_id
        LEFT JOIN transaction_items ti ON p.id = ti.product_id
            AND ti.created_at >= NOW() - interval '30 days'
            AND ti.store_id = current_user_store_id
        WHERE p.store_id = current_user_store_id
          AND pb.store_id = current_user_store_id
          AND pb.is_available = true
          AND p.is_active = true
        GROUP BY p.id, p.name, p.sku
        HAVING AVG(pb.quantity) > 0  -- Must have stock
        ORDER BY turnover_ratio ASC
        LIMIT 5
    ) t;

    RETURN jsonb_build_object(
        'top_value_products', top_value_products,
        'fast_turnover_products', fast_turnover_products,
        'slow_turnover_products', slow_turnover_products
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_inventory_alerts(int, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION get_inventory_analytics_lists() TO authenticated;
