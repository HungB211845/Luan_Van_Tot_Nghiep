-- =============================================================================
-- ROLLBACK MIGRATION: PO Sync Enhancement
-- Date: 2025-01-27
-- Author: AgriPOS Development Team
-- Purpose: Complete rollback to restore original system state before PO sync enhancement
-- 
-- ⚠️  WARNING: This will remove selling price functionality from PO workflow
-- Use only if critical issues occur with the enhancement migration
-- =============================================================================

-- =====================================================
-- 1. BACKUP SELLING PRICE DATA (OPTIONAL)
-- =====================================================

-- Uncomment below to backup selling price data before rollback
/*
CREATE TABLE IF NOT EXISTS purchase_order_items_selling_price_backup AS
SELECT 
    id,
    purchase_order_id,
    product_id,
    selling_price,
    profit_margin,
    price_updated_at,
    NOW() as backed_up_at
FROM purchase_order_items 
WHERE selling_price IS NOT NULL 
OR profit_margin IS NOT NULL 
OR price_updated_at IS NOT NULL;

RAISE NOTICE 'Selling price data backed up to purchase_order_items_selling_price_backup table';
*/

-- =====================================================
-- 2. DROP NEW VIEWS
-- =====================================================

-- Drop PO inventory impact view
DROP VIEW IF EXISTS po_inventory_impact CASCADE;

RAISE NOTICE 'Dropped po_inventory_impact view ✅';

-- =====================================================
-- 3. DROP NEW FUNCTIONS
-- =====================================================

-- Drop enhanced RPC function
DROP FUNCTION IF EXISTS create_batches_from_po(UUID);
DROP FUNCTION IF EXISTS get_po_price_analysis(UUID);

RAISE NOTICE 'Dropped enhanced RPC functions ✅';

-- =====================================================
-- 4. RESTORE ORIGINAL RPC FUNCTION
-- =====================================================

-- Restore original simple create_batches_from_po function
CREATE OR REPLACE FUNCTION create_batches_from_po(po_id UUID)
RETURNS INTEGER AS $$
DECLARE
  po_record RECORD;
  item_record RECORD;
  batch_count INTEGER := 0;
  new_batch_number TEXT;
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
  SELECT po.*, c.name as supplier_name
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

  -- Loop through PO items to create batches (ORIGINAL LOGIC ONLY)
  FOR item_record IN
    SELECT 
        poi.*, 
        p.name as product_name, 
        p.sku as product_sku
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
                       LPAD(batch_count + 1::TEXT, 2, '0');

    -- Create product batch (ORIGINAL FIELDS ONLY)
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
    );

    batch_count := batch_count + 1;
  END LOOP;

  -- Return simple batch count (original behavior)
  RETURN batch_count;

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error creating batches from PO %: %', po_id, SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION create_batches_from_po(UUID) TO authenticated;

RAISE NOTICE 'Restored original create_batches_from_po function ✅';

-- =====================================================
-- 5. REMOVE NEW COLUMNS FROM PURCHASE_ORDER_ITEMS
-- =====================================================

-- Check if selling_price column exists and remove it
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchase_order_items' 
        AND column_name = 'selling_price'
    ) THEN
        ALTER TABLE purchase_order_items DROP COLUMN selling_price;
        RAISE NOTICE 'Dropped selling_price column ✅';
    END IF;
END;
$$;

-- Check if profit_margin column exists and remove it
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchase_order_items' 
        AND column_name = 'profit_margin'
    ) THEN
        ALTER TABLE purchase_order_items DROP COLUMN profit_margin;
        RAISE NOTICE 'Dropped profit_margin column ✅';
    END IF;
END;
$$;

-- Check if price_updated_at column exists and remove it
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchase_order_items' 
        AND column_name = 'price_updated_at'
    ) THEN
        ALTER TABLE purchase_order_items DROP COLUMN price_updated_at;
        RAISE NOTICE 'Dropped price_updated_at column ✅';
    END IF;
END;
$$;

-- =====================================================
-- 6. DROP NEW INDEXES
-- =====================================================

-- Drop indexes that were created for the new columns
DROP INDEX IF EXISTS idx_purchase_order_items_selling_price;
DROP INDEX IF EXISTS idx_purchase_order_items_profit_margin;
DROP INDEX IF EXISTS idx_purchase_order_items_price_updated;

RAISE NOTICE 'Dropped new indexes ✅';

-- =====================================================
-- 7. CLEANUP COMMENTS
-- =====================================================

-- Remove column comments (they will be automatically removed with columns)
-- This is just for documentation
-- COMMENT ON COLUMN purchase_order_items.selling_price IS NULL; -- Column removed
-- COMMENT ON COLUMN purchase_order_items.profit_margin IS NULL; -- Column removed
-- COMMENT ON COLUMN purchase_order_items.price_updated_at IS NULL; -- Column removed

-- =====================================================
-- 8. VERIFICATION OF ROLLBACK
-- =====================================================

DO $$
BEGIN
    -- Verify columns were removed
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'purchase_order_items' 
        AND column_name IN ('selling_price', 'profit_margin', 'price_updated_at')
    ) THEN
        RAISE EXCEPTION 'Rollback failed: New columns still exist in purchase_order_items';
    END IF;

    -- Verify view was removed
    IF EXISTS (
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'po_inventory_impact'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: po_inventory_impact view still exists';
    END IF;

    -- Verify original function was restored
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'create_batches_from_po'
        AND routine_type = 'FUNCTION'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: create_batches_from_po function was not restored';
    END IF;

    -- Verify enhanced functions were removed
    IF EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'get_po_price_analysis'
        AND routine_type = 'FUNCTION'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: get_po_price_analysis function still exists';
    END IF;

    RAISE NOTICE 'Rollback verification completed successfully! ✅';
    RAISE NOTICE 'System has been restored to original state before PO sync enhancement.';
    RAISE NOTICE 'PO workflow will now work without selling price functionality.';
END;
$$;

-- =====================================================
-- 9. FINAL CLEANUP & NOTES
-- =====================================================

-- Note: Any price_history entries created by the enhanced PO workflow will remain
-- for audit purposes. They will not affect the system functionality.

-- Note: Any existing product_batches created with the enhanced function will remain
-- and continue to work normally.

-- Note: To restore selling price data later, use the backup table:
-- purchase_order_items_selling_price_backup (if created above)

-- =====================================================
-- END OF ROLLBACK
-- =====================================================

RAISE NOTICE '=================================================================';
RAISE NOTICE 'ROLLBACK COMPLETED SUCCESSFULLY';
RAISE NOTICE '=================================================================';
RAISE NOTICE 'The system has been restored to its original state.';
RAISE NOTICE 'PO workflow will work without selling price functionality.';
RAISE NOTICE 'All existing data has been preserved.';
RAISE NOTICE 'Check application logs to ensure frontend still works correctly.';
RAISE NOTICE '=================================================================';

COMMIT;