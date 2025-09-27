-- =============================================================================
-- MIGRATION: ADD UNIT COLUMN TO PURCHASE_ORDER_ITEMS
-- =============================================================================

ALTER TABLE public.purchase_order_items
ADD COLUMN unit TEXT;
