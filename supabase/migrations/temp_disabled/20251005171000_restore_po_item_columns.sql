-- Restore columns on purchase_order_items that were dropped by a previous rollback.
-- These columns are essential for price analysis and history from purchase orders.

BEGIN;

-- Add the three columns back with appropriate data types.
ALTER TABLE public.purchase_order_items
ADD COLUMN selling_price NUMERIC,
ADD COLUMN profit_margin NUMERIC,
ADD COLUMN price_updated_at TIMESTAMPTZ;

-- Add comments to document the purpose of these columns.
COMMENT ON COLUMN public.purchase_order_items.selling_price IS 'Suggested selling price for the product at the time of purchase, for reference.';
COMMENT ON COLUMN public.purchase_order_items.profit_margin IS 'Calculated profit margin based on unit cost and suggested selling price.';
COMMENT ON COLUMN public.purchase_order_items.price_updated_at IS 'Timestamp of when the selling price was last synced or updated from this PO item.';

COMMIT;
