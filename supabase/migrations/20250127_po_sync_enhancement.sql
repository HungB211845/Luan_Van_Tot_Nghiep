-- =============================================================================
-- MIGRATION: PO Sync Enhancement - Add Selling Price Support  
-- Date: 2025-01-27
-- Author: AgriPOS Development Team
-- Purpose: Enable Create PO to handle selling prices and sync with POS/History screens
-- =============================================================================

-- =====================================================
-- 1. ADD SELLING PRICE SUPPORT TO PO ITEMS
-- =====================================================

-- Add selling_price column to purchase_order_items
ALTER TABLE purchase_order_items 
ADD COLUMN selling_price NUMERIC DEFAULT NULL;

-- Add metadata columns for better tracking
ALTER TABLE purchase_order_items
ADD COLUMN profit_margin NUMERIC DEFAULT NULL,
ADD COLUMN price_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN purchase_order_items.selling_price IS 'Selling price set during PO creation, used to update product current_selling_price when PO is received';
COMMENT ON COLUMN purchase_order_items.profit_margin IS 'Calculated profit margin percentage: ((selling_price - unit_cost) / unit_cost) * 100';
COMMENT ON COLUMN purchase_order_items.price_updated_at IS 'Timestamp when selling price was last updated';

-- =====================================================
-- 2. CREATE PERFORMANCE INDEXES
-- =====================================================

-- Index for selling price queries
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_selling_price 
ON purchase_order_items (selling_price) WHERE selling_price IS NOT NULL;

-- Index for profit margin analysis
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_profit_margin 
ON purchase_order_items (profit_margin) WHERE profit_margin IS NOT NULL;

-- Index for PO items with price updates
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_price_updated 
ON purchase_order_items (price_updated_at) WHERE price_updated_at IS NOT NULL;

-- =====================================================
-- 3. CREATE PO INVENTORY IMPACT VIEW
-- =====================================================

-- View for analyzing inventory impact and profitability of POs
CREATE OR REPLACE VIEW po_inventory_impact AS
SELECT 
    po.id as po_id,
    po.po_number,
    po.status,
    po.delivery_date,
    po.supplier_id,
    s.name as supplier_name,
    COUNT(pb.id) as batch_count,
    SUM(pb.quantity) as total_quantity_received,
    SUM(pb.cost_price * pb.quantity) as total_cost_value,
    COUNT(CASE WHEN poi.selling_price > 0 THEN 1 END) as items_with_selling_price,
    AVG(CASE WHEN poi.selling_price > 0 AND poi.unit_cost > 0
        THEN ((poi.selling_price - poi.unit_cost) / poi.unit_cost * 100) 
        ELSE NULL END) as avg_profit_margin,
    SUM(CASE WHEN poi.selling_price > 0 
        THEN (poi.selling_price - poi.unit_cost) * poi.quantity
        ELSE 0 END) as total_profit_potential,
    po.created_at,
    po.store_id
FROM purchase_orders po
LEFT JOIN companies s ON po.supplier_id = s.id
LEFT JOIN product_batches pb ON po.id = pb.purchase_order_id
LEFT JOIN purchase_order_items poi ON po.id = poi.purchase_order_id 
    AND pb.product_id = poi.product_id
WHERE po.status IN ('DELIVERED', 'CONFIRMED')
GROUP BY po.id, po.po_number, po.status, po.delivery_date, po.supplier_id, 
         s.name, po.created_at, po.store_id;

-- Grant access to the view
GRANT SELECT ON po_inventory_impact TO authenticated;

-- Add RLS policy for store isolation
ALTER VIEW po_inventory_impact ENABLE ROW LEVEL SECURITY;
CREATE POLICY "po_inventory_impact_store_isolation" ON po_inventory_impact
    FOR SELECT TO authenticated
    USING (store_id = (SELECT store_id FROM user_profiles WHERE id = auth.uid()));

-- =====================================================
-- 4. CREATE ENHANCED RPC FUNCTION
-- =====================================================

-- Drop existing function to avoid conflicts
DROP FUNCTION IF EXISTS create_batches_from_po(UUID);

-- Create enhanced function with selling price support
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
RETURNS JSON AS $$
DECLARE
    po_record RECORD;
    item_record RECORD;
    batch_count INTEGER := 0;
    price_updates_count INTEGER := 0;
    new_batch_number TEXT;
    old_selling_price NUMERIC;
    batch_id UUID;
    user_store_id UUID;
BEGIN
    -- Get current user's store_id for security
    SELECT store_id INTO user_store_id
    FROM user_profiles 
    WHERE id = auth.uid();

    IF user_store_id IS NULL THEN
        RAISE EXCEPTION 'User not associated with any store';
    END IF;

    -- Get PO info with supplier
    SELECT 
        po.*, 
        c.name as supplier_name
    INTO po_record
    FROM purchase_orders po
    LEFT JOIN companies c ON po.supplier_id = c.id
    WHERE po.id = po_id
    AND po.store_id = user_store_id;  -- Security: store isolation

    -- Validate PO exists and user has access
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Purchase Order not found or access denied: %', po_id;
    END IF;

    -- Validate PO status
    IF po_record.status != 'DELIVERED' THEN
        RAISE EXCEPTION 'PO must be DELIVERED status to create batches, current status: %', po_record.status;
    END IF;

    -- Process each PO item to create batches
    FOR item_record IN
        SELECT 
            poi.*, 
            p.name as product_name, 
            p.sku as product_sku,
            p.current_selling_price as current_price
        FROM purchase_order_items poi
        INNER JOIN products p ON poi.product_id = p.id
        WHERE poi.purchase_order_id = po_id
        AND poi.quantity > 0
        AND p.store_id = user_store_id  -- Security: store isolation
        ORDER BY poi.created_at
    LOOP
        -- Generate unique batch number
        new_batch_number := COALESCE(po_record.po_number, 'PO') || '-' || 
                           COALESCE(SUBSTRING(item_record.product_sku FROM 1 FOR 6), 'PROD') || '-' || 
                           LPAD((batch_count + 1)::TEXT, 2, '0');

        -- Create product batch with all required information
        INSERT INTO product_batches (
            product_id,
            batch_number,
            quantity,
            cost_price,
            received_date,
            purchase_order_id,
            supplier_id,
            store_id,
            notes,
            is_available,
            is_deleted
        ) VALUES (
            item_record.product_id,
            new_batch_number,
            item_record.quantity,
            item_record.unit_cost,
            COALESCE(po_record.delivery_date::date, CURRENT_DATE),
            po_id,
            po_record.supplier_id,
            user_store_id,
            'Auto-created from PO: ' || COALESCE(po_record.po_number, po_id::text),
            true,
            false
        ) RETURNING id INTO batch_id;

        -- ✅ NEW FEATURE: Update selling price if provided in PO item
        IF item_record.selling_price IS NOT NULL AND item_record.selling_price > 0 THEN
            -- Store old price for history tracking
            old_selling_price := item_record.current_price;
            
            -- Update product's current selling price
            UPDATE products 
            SET 
                current_selling_price = item_record.selling_price,
                updated_at = NOW()
            WHERE id = item_record.product_id 
            AND store_id = user_store_id;

            -- Create price history entry for audit trail
            INSERT INTO price_history (
                product_id,
                new_price,
                old_price,
                reason,
                user_id_who_changed,
                store_id,
                created_at
            ) VALUES (
                item_record.product_id,
                item_record.selling_price,
                old_selling_price,
                'Updated from Purchase Order: ' || COALESCE(po_record.po_number, 'PO-' || po_id::text),
                auth.uid(),
                user_store_id,
                NOW()
            );

            -- Update PO item with calculated profit margin and timestamp
            UPDATE purchase_order_items
            SET 
                profit_margin = CASE 
                    WHEN item_record.unit_cost > 0 
                    THEN ((item_record.selling_price - item_record.unit_cost) / item_record.unit_cost * 100)
                    ELSE NULL 
                END,
                price_updated_at = NOW()
            WHERE id = item_record.id;

            price_updates_count := price_updates_count + 1;
        END IF;

        batch_count := batch_count + 1;
    END LOOP;

    -- Return comprehensive summary
    RETURN json_build_object(
        'success', true,
        'po_id', po_id,
        'po_number', po_record.po_number,
        'supplier_name', po_record.supplier_name,
        'batches_created', batch_count,
        'prices_updated', price_updates_count,
        'delivery_date', po_record.delivery_date,
        'message', format('Successfully created %s batches and updated %s product prices from PO %s', 
                         batch_count, price_updates_count, COALESCE(po_record.po_number, 'Unknown')),
        'timestamp', NOW()
    );

EXCEPTION
    WHEN OTHERS THEN
        -- Return detailed error information for debugging
        RETURN json_build_object(
            'success', false,
            'error_code', SQLSTATE,
            'error_message', SQLERRM,
            'po_id', po_id,
            'batches_created', COALESCE(batch_count, 0),
            'prices_updated', COALESCE(price_updates_count, 0),
            'timestamp', NOW()
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION create_batches_from_po(UUID) TO authenticated;

-- =====================================================
-- 5. CREATE HELPER FUNCTION FOR PO PRICE ANALYSIS
-- =====================================================

-- Function to get price analysis for a specific PO
CREATE OR REPLACE FUNCTION get_po_price_analysis(po_id UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
    user_store_id UUID;
BEGIN
    -- Get current user's store_id for security
    SELECT store_id INTO user_store_id
    FROM user_profiles 
    WHERE id = auth.uid();

    IF user_store_id IS NULL THEN
        RAISE EXCEPTION 'User not associated with any store';
    END IF;

    -- Build price analysis
    SELECT json_build_object(
        'po_id', po.id,
        'po_number', po.po_number,
        'status', po.status,
        'total_items', COUNT(poi.id),
        'items_with_selling_price', COUNT(CASE WHEN poi.selling_price > 0 THEN 1 END),
        'total_cost', SUM(poi.unit_cost * poi.quantity),
        'total_selling_value', SUM(CASE WHEN poi.selling_price > 0 
                                      THEN poi.selling_price * poi.quantity 
                                      ELSE 0 END),
        'avg_profit_margin', AVG(CASE WHEN poi.selling_price > 0 AND poi.unit_cost > 0
                                    THEN ((poi.selling_price - poi.unit_cost) / poi.unit_cost * 100)
                                    ELSE NULL END),
        'price_coverage_percentage', ROUND((COUNT(CASE WHEN poi.selling_price > 0 THEN 1 END)::NUMERIC / 
                                          NULLIF(COUNT(poi.id), 0) * 100), 2)
    ) INTO result
    FROM purchase_orders po
    LEFT JOIN purchase_order_items poi ON po.id = poi.purchase_order_id
    WHERE po.id = get_po_price_analysis.po_id
    AND po.store_id = user_store_id
    GROUP BY po.id, po.po_number, po.status;

    RETURN COALESCE(result, json_build_object('error', 'PO not found or no access'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_po_price_analysis(UUID) TO authenticated;

-- =====================================================
-- 6. UPDATE RLS POLICIES (if needed)
-- =====================================================

-- Ensure purchase_order_items has proper RLS for new columns
-- The existing RLS policies should cover the new columns automatically

-- =====================================================
-- 7. VERIFICATION QUERY
-- =====================================================

-- Test that the migration worked correctly
DO $$
BEGIN
    -- Check if columns were added
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchase_order_items' 
        AND column_name = 'selling_price'
    ) THEN
        RAISE EXCEPTION 'selling_price column was not created';
    END IF;

    -- Check if view was created
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'po_inventory_impact'
    ) THEN
        RAISE EXCEPTION 'po_inventory_impact view was not created';
    END IF;

    -- Check if function was created
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'create_batches_from_po'
        AND routine_type = 'FUNCTION'
    ) THEN
        RAISE EXCEPTION 'create_batches_from_po function was not created';
    END IF;

    RAISE NOTICE 'Migration completed successfully! ✅';
END;
$$;

-- =====================================================
-- 8. SAMPLE DATA UPDATE (Optional - for testing)
-- =====================================================

-- Uncomment below to add sample selling prices to existing PO items for testing
/*
UPDATE purchase_order_items 
SET selling_price = unit_cost * (1.2 + (RANDOM() * 0.3))  -- 20-50% markup
WHERE selling_price IS NULL 
AND unit_cost > 0
AND purchase_order_id IN (
    SELECT id FROM purchase_orders 
    WHERE status = 'DELIVERED' 
    AND created_at > NOW() - INTERVAL '30 days'
    LIMIT 5
);
*/

-- =====================================================
-- END OF MIGRATION
-- =====================================================

COMMIT;