-- Restore critical performance indexes that were dropped by a previous rollback.
-- These indexes are essential for speeding up product loading and stock calculations.

-- Restore critical index for calculating product stock efficiently.
-- This index speeds up the SUM() and GROUP BY on product_batches for a specific store.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_batches_stock_calc
ON public.product_batches (store_id, product_id);

-- Restore index for quickly filtering products by store.
-- Essential for all multi-tenant queries on the products table.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_store_id
ON public.products (store_id);

-- Restore index for checking available batches, useful for stock checks.
-- This is a partial index for better performance on a common query pattern.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_batches_stock_check
ON public.product_batches (store_id, product_id, is_available)
WHERE is_available = true;

-- Restore index for price history lookups.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_price_history_product_store
ON public.price_history (store_id, product_id);
