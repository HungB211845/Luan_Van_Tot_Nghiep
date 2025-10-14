-- ARCHITECTURAL FIX: Move all filtering logic to the database RPC.
-- This makes the database the single source of truth for filtering and sorting,
-- resolving inconsistencies and client-side state bugs.

DROP FUNCTION IF EXISTS public.search_purchase_orders(text, uuid[], text, boolean);

-- Recreate with all filter parameters
CREATE OR REPLACE FUNCTION public.search_purchase_orders(
    p_search_text TEXT DEFAULT NULL,
    p_supplier_ids UUID[] DEFAULT NULL,
    p_status_filters TEXT[] DEFAULT NULL, -- NEW: Status filter
    p_from_date DATE DEFAULT NULL,        -- NEW: Date range filter
    p_to_date DATE DEFAULT NULL,          -- NEW: Date range filter
    p_min_total NUMERIC DEFAULT NULL,     -- NEW: Amount range filter
    p_max_total NUMERIC DEFAULT NULL,     -- NEW: Amount range filter
    p_sort_by TEXT DEFAULT 'order_date',
    p_sort_asc BOOLEAN DEFAULT FALSE
)
RETURNS SETOF purchase_orders_with_details 
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    current_store_id uuid;
BEGIN
    -- Get current user's store_id
    SELECT store_id INTO current_store_id
    FROM user_profiles
    WHERE id = auth.uid();
    
    IF current_store_id IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT po.*
    FROM purchase_orders_with_details po
    WHERE
        -- MANDATORY: Store isolation
        po.store_id = current_store_id
    AND
        -- Search filter
        (p_search_text IS NULL OR p_search_text = '' OR
         po.po_number ILIKE '%' || p_search_text || '%' OR
         po.supplier_name ILIKE '%' || p_search_text || '%')
    AND
        -- Supplier filter
        (p_supplier_ids IS NULL OR po.supplier_id = ANY(p_supplier_ids))
    AND 
        -- NEW: Status filter
        (p_status_filters IS NULL OR po.status = ANY(p_status_filters))
    AND
        -- NEW: Date range filter
        (p_from_date IS NULL OR po.order_date >= p_from_date)
    AND
        (p_to_date IS NULL OR po.order_date <= p_to_date)
    AND
        -- NEW: Amount range filter
        (p_min_total IS NULL OR po.total_amount >= p_min_total)
    AND
        (p_max_total IS NULL OR po.total_amount <= p_max_total)
    ORDER BY
        CASE WHEN p_sort_by = 'order_date' AND p_sort_asc THEN po.order_date END ASC,
        CASE WHEN p_sort_by = 'order_date' AND NOT p_sort_asc THEN po.order_date END DESC,
        CASE WHEN p_sort_by = 'total_amount' AND p_sort_asc THEN po.total_amount END ASC,
        CASE WHEN p_sort_by = 'total_amount' AND NOT p_sort_asc THEN po.total_amount END DESC,
        po.created_at DESC; -- Tie-breaker
END; $$;

GRANT EXECUTE ON FUNCTION public.search_purchase_orders(text, uuid[], text[], date, date, numeric, numeric, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.search_purchase_orders(text, uuid[], text[], date, date, numeric, numeric, text, boolean) IS 
'Full-featured, store-aware search for purchase orders.';
