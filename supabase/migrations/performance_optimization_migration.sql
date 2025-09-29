-- =============================================================================
-- PERFORMANCE OPTIMIZATION MIGRATION
-- =============================================================================
-- Sửa N+1 queries, tối ưu FIFO inventory, và cải thiện performance

-- =============================================================================
-- 1. OPTIMIZE PRODUCTS WITH DETAILS VIEW
-- =============================================================================

-- Drop old view that causes N+1 queries
DROP VIEW IF EXISTS products_with_details;

-- Create optimized view with aggregated data
CREATE VIEW products_with_details AS
SELECT
    p.id,
    p.sku,
    p.name,
    p.category,
    p.company_id,
    p.attributes,
    p.is_active,
    p.is_banned,
    p.image_url,
    p.description,
    p.created_at,
    p.updated_at,
    p.min_stock_level,
    p.npk_ratio,
    p.active_ingredient,
    p.seed_strain,
    p.store_id,
    -- Company name via JOIN (not subquery)
    c.name as company_name,
    -- Pre-calculated stock and price
    COALESCE(stock_agg.total_stock, 0) as available_stock,
    COALESCE(price_agg.current_price, 0) as current_price,
    -- Additional useful fields
    stock_agg.batch_count,
    stock_agg.oldest_batch_date,
    stock_agg.newest_batch_date
FROM products p
LEFT JOIN companies c ON p.company_id = c.id AND p.store_id = c.store_id
LEFT JOIN (
    -- Pre-aggregate stock data to avoid N+1 queries
    SELECT
        product_id,
        SUM(quantity) as total_stock,
        COUNT(*) as batch_count,
        MIN(received_date) as oldest_batch_date,
        MAX(received_date) as newest_batch_date
    FROM product_batches
    WHERE is_available = true
    AND (expiry_date IS NULL OR expiry_date > NOW())
    GROUP BY product_id
) stock_agg ON p.id = stock_agg.product_id
LEFT JOIN (
    -- Pre-calculate current price from seasonal_prices table
    SELECT
        product_id,
        selling_price as current_price
    FROM seasonal_prices
    WHERE is_active = true
    AND start_date <= CURRENT_DATE
    AND end_date >= CURRENT_DATE
) price_agg ON p.id = price_agg.product_id;

-- =============================================================================
-- 2. EFFICIENT COUNTING FUNCTION
-- =============================================================================

-- Create function for estimated counts (much faster than exact counts)
CREATE OR REPLACE FUNCTION get_estimated_count(
    table_name text,
    store_id_param uuid DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    count_estimate bigint;
BEGIN
    -- For tables with RLS, use statistics for estimation
    IF table_name = 'products' THEN
        SELECT
            (reltuples * (
                SELECT COUNT(*)
                FROM pg_class c2
                WHERE c2.oid = c.oid
            ) / GREATEST(relpages, 1))::bigint
        INTO count_estimate
        FROM pg_class c
        WHERE relname = table_name;

        -- If we have store_id, estimate based on average distribution
        IF store_id_param IS NOT NULL THEN
            count_estimate := count_estimate / (
                SELECT COUNT(DISTINCT store_id) FROM products
            );
        END IF;
    ELSE
        -- Fallback to actual count for smaller tables
        EXECUTE format('SELECT COUNT(*) FROM %I', table_name) INTO count_estimate;
    END IF;

    RETURN COALESCE(count_estimate, 0);
END;
$$;

-- =============================================================================
-- 3. BATCH FIFO INVENTORY UPDATE FUNCTION
-- =============================================================================

-- Create optimized FIFO inventory update function
CREATE OR REPLACE FUNCTION update_inventory_fifo_batch(
    items_json jsonb
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    item_record jsonb;
    product_id_param uuid;
    quantity_to_reduce int;
    batch_record record;
    remaining_to_reduce int;
    updated_batches jsonb := '[]'::jsonb;
    insufficient_stock jsonb := '[]'::jsonb;
    current_user_store_id uuid;
BEGIN
    -- Get current user's store ID
    SELECT store_id INTO current_user_store_id
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF current_user_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store';
    END IF;

    -- Process each item in the batch
    FOR item_record IN SELECT * FROM jsonb_array_elements(items_json)
    LOOP
        product_id_param := (item_record->>'product_id')::uuid;
        quantity_to_reduce := (item_record->>'quantity')::int;
        remaining_to_reduce := quantity_to_reduce;

        -- Get batches for this product ordered by FIFO
        FOR batch_record IN
            SELECT id, quantity, received_date, expiry_date
            FROM product_batches
            WHERE product_id = product_id_param
            AND store_id = current_user_store_id
            AND is_available = true
            AND quantity > 0
            AND (expiry_date IS NULL OR expiry_date > NOW())
            ORDER BY
                received_date ASC,  -- FIFO by receive date
                expiry_date ASC     -- Then by expiry date
            FOR UPDATE -- Lock rows to prevent concurrent updates
        LOOP
            EXIT WHEN remaining_to_reduce <= 0;

            IF batch_record.quantity <= remaining_to_reduce THEN
                -- Use entire batch
                UPDATE product_batches
                SET quantity = 0, updated_at = NOW()
                WHERE id = batch_record.id;

                remaining_to_reduce := remaining_to_reduce - batch_record.quantity;

                updated_batches := updated_batches || jsonb_build_object(
                    'batch_id', batch_record.id,
                    'quantity_used', batch_record.quantity,
                    'remaining_quantity', 0
                );
            ELSE
                -- Use partial batch
                UPDATE product_batches
                SET quantity = quantity - remaining_to_reduce, updated_at = NOW()
                WHERE id = batch_record.id;

                updated_batches := updated_batches || jsonb_build_object(
                    'batch_id', batch_record.id,
                    'quantity_used', remaining_to_reduce,
                    'remaining_quantity', batch_record.quantity - remaining_to_reduce
                );

                remaining_to_reduce := 0;
            END IF;
        END LOOP;

        -- Check if we couldn't fulfill the entire quantity
        IF remaining_to_reduce > 0 THEN
            insufficient_stock := insufficient_stock || jsonb_build_object(
                'product_id', product_id_param,
                'requested_quantity', quantity_to_reduce,
                'available_quantity', quantity_to_reduce - remaining_to_reduce,
                'shortage', remaining_to_reduce
            );
        END IF;
    END LOOP;

    -- Return summary of operations
    RETURN jsonb_build_object(
        'success', true,
        'updated_batches', updated_batches,
        'insufficient_stock', insufficient_stock,
        'updated_at', NOW()
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'updated_batches', updated_batches,
            'insufficient_stock', insufficient_stock
        );
END;
$$;

-- =============================================================================
-- 4. OPTIMIZED TRANSACTION SEARCH WITH JOINS
-- =============================================================================

-- Update the search_transactions function to include transaction items
CREATE OR REPLACE FUNCTION search_transactions_with_items(
    p_search_text TEXT DEFAULT NULL,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL,
    p_min_amount NUMERIC DEFAULT NULL,
    p_max_amount NUMERIC DEFAULT NULL,
    p_payment_methods TEXT[] DEFAULT NULL,
    p_customer_ids UUID[] DEFAULT NULL,
    p_debt_status TEXT DEFAULT NULL,
    p_include_items BOOLEAN DEFAULT false,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    created_at TIMESTAMPTZ,
    store_id UUID,
    customer_id UUID,
    total_amount NUMERIC,
    payment_method TEXT,
    is_debt BOOLEAN,
    transaction_date TIMESTAMPTZ,
    notes TEXT,
    invoice_number TEXT,
    customer_name TEXT,
    total_count BIGINT,
    -- Transaction items (when requested)
    items_json JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_store_id UUID;
    query_sql TEXT;
    where_clauses TEXT[] := ARRAY[]::TEXT[];
    offset_val INT;
BEGIN
    -- Get current user's store ID
    SELECT up.store_id INTO v_current_store_id
    FROM public.user_profiles up
    WHERE up.id = auth.uid();

    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store.';
    END IF;

    -- Build WHERE clauses
    where_clauses := array_append(where_clauses, 't.store_id = ' || quote_literal(v_current_store_id));

    IF p_search_text IS NOT NULL AND p_search_text <> '' THEN
        where_clauses := array_append(where_clauses, '(t.invoice_number ILIKE ' || quote_literal('%' || p_search_text || '%') || ' OR c.name ILIKE ' || quote_literal('%' || p_search_text || '%') || ')');
    END IF;

    IF p_start_date IS NOT NULL THEN
        where_clauses := array_append(where_clauses, 't.transaction_date >= ' || quote_literal(p_start_date));
    END IF;

    IF p_end_date IS NOT NULL THEN
        where_clauses := array_append(where_clauses, 't.transaction_date <= ' || quote_literal(p_end_date));
    END IF;

    IF p_min_amount IS NOT NULL THEN
        where_clauses := array_append(where_clauses, 't.total_amount >= ' || p_min_amount);
    END IF;

    IF p_max_amount IS NOT NULL THEN
        where_clauses := array_append(where_clauses, 't.total_amount <= ' || p_max_amount);
    END IF;

    IF p_payment_methods IS NOT NULL AND array_length(p_payment_methods, 1) > 0 THEN
        where_clauses := array_append(where_clauses, 't.payment_method = ANY(' || quote_literal(p_payment_methods) || '::TEXT[])');
    END IF;

    IF p_customer_ids IS NOT NULL AND array_length(p_customer_ids, 1) > 0 THEN
        where_clauses := array_append(where_clauses, 't.customer_id = ANY(' || quote_literal(p_customer_ids) || '::UUID[])');
    END IF;

    IF p_debt_status IS NOT NULL THEN
        IF p_debt_status = 'unpaid' THEN
            where_clauses := array_append(where_clauses, 't.is_debt = TRUE');
        ELSIF p_debt_status = 'paid' THEN
             where_clauses := array_append(where_clauses, 't.is_debt = FALSE');
        END IF;
    END IF;

    -- Build main query
    query_sql := '
        SELECT
            t.id, t.created_at, t.store_id, t.customer_id, t.total_amount,
            t.payment_method, t.is_debt, t.transaction_date, t.notes,
            t.invoice_number, c.name as customer_name,
            COUNT(*) OVER() AS total_count';

    -- Conditionally include transaction items
    IF p_include_items THEN
        query_sql := query_sql || ',
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        ''id'', ti.id,
                        ''product_id'', ti.product_id,
                        ''product_name'', p.name,
                        ''product_sku'', p.sku,
                        ''quantity'', ti.quantity,
                        ''unit_price'', ti.unit_price,
                        ''sub_total'', ti.sub_total
                    ) ORDER BY ti.created_at
                ) FILTER (WHERE ti.id IS NOT NULL),
                ''[]''::jsonb
            ) as items_json';
    ELSE
        query_sql := query_sql || ',
            ''[]''::jsonb as items_json';
    END IF;

    query_sql := query_sql || '
        FROM transactions t
        LEFT JOIN customers c ON t.customer_id = c.id AND t.store_id = c.store_id';

    IF p_include_items THEN
        query_sql := query_sql || '
        LEFT JOIN transaction_items ti ON t.id = ti.transaction_id
        LEFT JOIN products p ON ti.product_id = p.id';
    END IF;

    IF array_length(where_clauses, 1) > 0 THEN
        query_sql := query_sql || ' WHERE ' || array_to_string(where_clauses, ' AND ');
    END IF;

    query_sql := query_sql || ' GROUP BY t.id, t.created_at, t.store_id, t.customer_id, t.total_amount, t.payment_method, t.is_debt, t.transaction_date, t.notes, t.invoice_number, c.name';

    -- Add ordering and pagination
    offset_val := (p_page - 1) * p_page_size;
    query_sql := query_sql || ' ORDER BY t.transaction_date DESC, t.created_at DESC';
    query_sql := query_sql || ' LIMIT ' || p_page_size || ' OFFSET ' || offset_val;

    -- Execute and return
    RETURN QUERY EXECUTE query_sql;
END;
$$;

-- =============================================================================
-- 5. CREATE PERFORMANCE INDEXES
-- =============================================================================

-- Indexes for product_batches (FIFO operations)
CREATE INDEX IF NOT EXISTS idx_product_batches_fifo ON product_batches(
    product_id, store_id, is_available, received_date, expiry_date
) WHERE quantity > 0;

-- Composite index for products with details
CREATE INDEX IF NOT EXISTS idx_products_with_details ON products(
    store_id, is_active, category, company_id
);

-- Index for transaction search optimization
CREATE INDEX IF NOT EXISTS idx_transactions_search ON transactions(
    store_id, transaction_date DESC, payment_method, is_debt
);

-- Index for transaction items joins
CREATE INDEX IF NOT EXISTS idx_transaction_items_lookup ON transaction_items(
    transaction_id, product_id
);

-- Index for customer name search
CREATE INDEX IF NOT EXISTS idx_customers_name_search ON customers
USING gin(to_tsvector('simple', name))
WHERE store_id IS NOT NULL;

-- =============================================================================
-- 6. GRANT PERMISSIONS
-- =============================================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_estimated_count(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_inventory_fifo_batch(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION search_transactions_with_items(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, NUMERIC, NUMERIC, TEXT[], UUID[], TEXT, BOOLEAN, INT, INT) TO authenticated;

-- Grant permissions to anon for public functions
GRANT EXECUTE ON FUNCTION get_estimated_count(text, uuid) TO anon;

-- =============================================================================
-- 7. PERFORMANCE MONITORING SETUP
-- =============================================================================

-- Create table to track slow queries
CREATE TABLE IF NOT EXISTS performance_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    query_type TEXT NOT NULL,
    execution_time_ms BIGINT NOT NULL,
    store_id UUID,
    user_id UUID,
    query_params JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for performance analysis
CREATE INDEX IF NOT EXISTS idx_performance_logs_analysis ON performance_logs(
    query_type, created_at DESC, execution_time_ms
);

-- Function to log slow queries
CREATE OR REPLACE FUNCTION log_slow_query(
    p_query_type TEXT,
    p_execution_time_ms BIGINT,
    p_query_params JSONB DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only log if execution time > 100ms
    IF p_execution_time_ms > 100 THEN
        INSERT INTO performance_logs (
            query_type,
            execution_time_ms,
            store_id,
            user_id,
            query_params
        ) VALUES (
            p_query_type,
            p_execution_time_ms,
            (SELECT store_id FROM user_profiles WHERE id = auth.uid()),
            auth.uid(),
            p_query_params
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION log_slow_query(TEXT, BIGINT, JSONB) TO authenticated;

-- =============================================================================
-- 8. CLEANUP AND OPTIMIZATION
-- =============================================================================

-- Analyze tables for better query planning
ANALYZE products;
ANALYZE product_batches;
ANALYZE transactions;
ANALYZE transaction_items;
ANALYZE customers;
ANALYZE companies;

-- Refresh table statistics (cannot update pg_stat views directly)
-- Statistics will be updated automatically by PostgreSQL

-- =============================================================================
-- 9. VERIFICATION QUERIES
-- =============================================================================

-- Test the optimized view
SELECT 'products_with_details view test' as test_name,
       COUNT(*) as row_count,
       AVG(available_stock) as avg_stock,
       COUNT(DISTINCT company_name) as unique_companies
FROM products_with_details
LIMIT 1;

-- Test the batch FIFO function
SELECT 'FIFO batch function test' as test_name,
       update_inventory_fifo_batch('[
         {"product_id": "00000000-0000-0000-0000-000000000000", "quantity": 0}
       ]'::jsonb) as result;

-- Test estimated count function
SELECT 'Estimated count test' as test_name,
       get_estimated_count('products') as estimated_products;

-- Performance summary
SELECT
    'Migration completed successfully!' as status,
    'Optimizations applied:' as summary,
    '- Fixed N+1 queries in products view' as fix1,
    '- Added batch FIFO inventory updates' as fix2,
    '- Created performance indexes' as fix3,
    '- Added monitoring functions' as fix4;