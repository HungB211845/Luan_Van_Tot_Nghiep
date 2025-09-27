-- supabase/migrations/20250925202200_create_po_search_function.sql

CREATE OR REPLACE FUNCTION search_purchase_orders(
    p_search_text TEXT DEFAULT NULL,
    p_supplier_ids UUID[] DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'order_date',
    p_sort_asc BOOLEAN DEFAULT FALSE
)
RETURNS SETOF purchase_orders_with_details AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT po.*
    FROM purchase_orders_with_details po
    -- Join with items and products only when searching text to find POs by product name
    LEFT JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
    LEFT JOIN products p ON p.id = poi.product_id
    WHERE
        -- Search filter (searches PO number, supplier name, and product names inside the PO)
        (p_search_text IS NULL OR p_search_text = '' OR
         po.po_number ILIKE '%' || p_search_text || '%' OR
         po.supplier_name ILIKE '%' || p_search_text || '%' OR
         p.name ILIKE '%' || p_search_text || '%')
    AND
        -- Supplier filter
        (p_supplier_ids IS NULL OR po.supplier_id = ANY(p_supplier_ids))
    ORDER BY
        CASE WHEN p_sort_by = 'order_date' AND p_sort_asc THEN po.order_date END ASC,
        CASE WHEN p_sort_by = 'order_date' AND NOT p_sort_asc THEN po.order_date END DESC,
        CASE WHEN p_sort_by = 'total_amount' AND p_sort_asc THEN po.total_amount END ASC,
        CASE WHEN p_sort_by = 'total_amount' AND NOT p_sort_asc THEN po.total_amount END DESC
    LIMIT 200; -- Add a reasonable limit to prevent performance issues
END;
$$ LANGUAGE plpgsql;
