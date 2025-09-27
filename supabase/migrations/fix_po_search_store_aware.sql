-- =============================================================================
-- URGENT FIX: STORE-AWARE SEARCH_PURCHASE_ORDERS FUNCTION
-- =============================================================================

-- Drop the vulnerable version
DROP FUNCTION IF EXISTS search_purchase_orders(TEXT, UUID[], TEXT, BOOLEAN);

-- Create store-aware version
CREATE OR REPLACE FUNCTION search_purchase_orders(
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
    -- SECURITY: Get current user's store_id
    SELECT store_id INTO current_store_id
    FROM user_profiles
    WHERE id = auth.uid();
    
    IF current_store_id IS NULL THEN
        -- Return empty result if user has no store access
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT DISTINCT po.*
    FROM purchase_orders_with_details po
    -- Join with items and products only when searching text
    LEFT JOIN purchase_order_items poi ON poi.purchase_order_id = po.id
    LEFT JOIN products p ON p.id = poi.product_id
    WHERE
        -- CRITICAL: Filter by current user's store
        po.store_id = current_store_id
    AND
        -- Search filter (searches PO number, supplier name, and product names)
        (p_search_text IS NULL OR p_search_text = '' OR
         po.po_number ILIKE '%' || p_search_text || '%' OR
         po.supplier_name ILIKE '%' || p_search_text || '%' OR
         p.name ILIKE '%' || p_search_text || '%')
    AND
        -- Supplier filter (also ensure supplier belongs to same store)
        (p_supplier_ids IS NULL OR (
            po.supplier_id = ANY(p_supplier_ids) AND
            EXISTS (
                SELECT 1 FROM companies c 
                WHERE c.id = po.supplier_id 
                AND c.store_id = current_store_id
            )
        ))
    ORDER BY
        CASE WHEN p_sort_by = 'order_date' AND p_sort_asc THEN po.order_date END ASC,
        CASE WHEN p_sort_by = 'order_date' AND NOT p_sort_asc THEN po.order_date END DESC,
        CASE WHEN p_sort_by = 'total_amount' AND p_sort_asc THEN po.total_amount END ASC,
        CASE WHEN p_sort_by = 'total_amount' AND NOT p_sort_asc THEN po.total_amount END DESC
    LIMIT 200;
END; $$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION search_purchase_orders(TEXT, UUID[], TEXT, BOOLEAN) TO authenticated;

-- Add comment
COMMENT ON FUNCTION search_purchase_orders(TEXT, UUID[], TEXT, BOOLEAN) IS 
'Store-aware search for purchase orders. Only returns POs from current user store.';