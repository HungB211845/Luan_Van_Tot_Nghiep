-- =============================================================================
-- MIGRATION: ADD PO FIELDS TO PRODUCT_BATCHES TABLE
-- Thêm purchase_order_id và supplier_id vào product_batches
-- =============================================================================

-- Add purchase_order_id column
ALTER TABLE product_batches
ADD COLUMN IF NOT EXISTS purchase_order_id UUID REFERENCES purchase_orders(id);

-- Add supplier_id column
ALTER TABLE product_batches
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES companies(id);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_product_batches_po
ON product_batches(purchase_order_id);

CREATE INDEX IF NOT EXISTS idx_product_batches_supplier
ON product_batches(supplier_id);

-- Add comments for documentation
COMMENT ON COLUMN product_batches.purchase_order_id IS
'Reference to the purchase order that created this batch';

COMMENT ON COLUMN product_batches.supplier_id IS
'Reference to the supplier who provided this batch';

-- Verify the columns were added successfully
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'product_batches'
AND column_name IN ('purchase_order_id', 'supplier_id');