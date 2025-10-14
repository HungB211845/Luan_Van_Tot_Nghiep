-- Fixes the purchase order search RPC to ensure correct sorting.
-- Adds `created_at DESC` as a secondary, deterministic sort key.
-- This guarantees that when multiple POs exist on the same day, the most recently created one always appears first.

DROP FUNCTION IF EXISTS public.search_purchase_orders(text, uuid[], text, boolean);

CREATE OR REPLACE FUNCTION public.search_purchase_orders(
    p_search_text TEXT DEFAULT NULL,
    p_supplier_ids UUID[] DEFAULT NULL,
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
        po.store_id = current_store_id
    AND
        (p_search_text IS NULL OR p_search_text = '' OR
         po.po_number ILIKE '%' || p_search_text || '%' OR
         po.supplier_name ILIKE '%' || p_search_text || '%')
    AND
        (p_supplier_ids IS NULL OR po.supplier_id = ANY(p_supplier_ids))
    ORDER BY
        CASE WHEN p_sort_by = 'order_date' AND p_sort_asc THEN po.order_date END ASC,
        CASE WHEN p_sort_by = 'order_date' AND NOT p_sort_asc THEN po.order_date END DESC,
        CASE WHEN p_sort_by = 'total_amount' AND p_sort_asc THEN po.total_amount END ASC,
        CASE WHEN p_sort_by = 'total_amount' AND NOT p_sort_asc THEN po.total_amount END DESC,
        po.created_at DESC; -- TIE-BREAKER: Always sort by creation time to ensure newest is first
END; $$;

GRANT EXECUTE ON FUNCTION public.search_purchase_orders(text, uuid[], text, boolean) TO authenticated;

COMMENT ON FUNCTION public.search_purchase_orders(TEXT, UUID[], TEXT, BOOLEAN) IS 
'Searches purchase orders with deterministic sorting.';
