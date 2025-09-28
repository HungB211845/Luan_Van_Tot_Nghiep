-- =============================================================================
-- FIX SEARCH_TRANSACTIONS RPC FUNCTION
-- =============================================================================
-- Sửa lỗi UUID casting trong function search_transactions

CREATE OR REPLACE FUNCTION search_transactions(
    p_search_text TEXT DEFAULT NULL,
    p_start_date TIMESTAMPTZ DEFAULT NULL,
    p_end_date TIMESTAMPTZ DEFAULT NULL,
    p_min_amount NUMERIC DEFAULT NULL,
    p_max_amount NUMERIC DEFAULT NULL,
    p_payment_methods TEXT[] DEFAULT NULL,
    p_customer_ids UUID[] DEFAULT NULL,
    p_debt_status TEXT DEFAULT NULL, -- 'paid', 'unpaid', 'all'
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
    customer_name TEXT, -- Joined from customers table
    total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER -- This bypasses RLS policies for store validation
AS $$
DECLARE
    v_current_store_id UUID; -- Renamed variable to avoid ambiguity
    query_sql TEXT;
    where_clauses TEXT[] := ARRAY[]::TEXT[];
    offset_val INT;
BEGIN
    -- 1. Security: Get the store_id of the currently authenticated user
    -- FIXED: Remove ::text casting since both sides are UUID
    SELECT up.store_id INTO v_current_store_id
    FROM public.user_profiles up
    WHERE up.id = auth.uid();

    IF v_current_store_id IS NULL THEN
        RAISE EXCEPTION 'User does not belong to a store.';
    END IF;

    -- 2. Build WHERE clauses based on filters
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

    -- FIXED: Use proper array syntax for payment methods
    IF p_payment_methods IS NOT NULL AND array_length(p_payment_methods, 1) > 0 THEN
        where_clauses := array_append(where_clauses, 't.payment_method = ANY(' || quote_literal(p_payment_methods) || '::TEXT[])');
    END IF;

    -- FIXED: Use proper array syntax for customer IDs
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

    -- 3. Construct the main query
    query_sql := '
        SELECT
            t.id, t.created_at, t.store_id, t.customer_id, t.total_amount,
            t.payment_method, t.is_debt, t.transaction_date, t.notes,
            t.invoice_number, c.name as customer_name,
            COUNT(*) OVER() AS total_count
        FROM transactions t
        LEFT JOIN customers c ON t.customer_id = c.id AND t.store_id = c.store_id';

    IF array_length(where_clauses, 1) > 0 THEN
        query_sql := query_sql || ' WHERE ' || array_to_string(where_clauses, ' AND ');
    END IF;

    -- 4. Add ordering and pagination
    offset_val := (p_page - 1) * p_page_size;
    query_sql := query_sql || ' ORDER BY t.transaction_date DESC, t.created_at DESC';
    query_sql := query_sql || ' LIMIT ' || p_page_size || ' OFFSET ' || offset_val;

    -- 5. Execute and return the results
    RETURN QUERY EXECUTE query_sql;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION search_transactions(TEXT, TIMESTAMPTZ, TIMESTAMPTZ, NUMERIC, NUMERIC, TEXT[], UUID[], TEXT, INT, INT) TO authenticated;

-- Test the function
SELECT 'search_transactions function updated successfully!' as status;