-- =============================================================================
-- DATABASE OPTIMIZATION - INDEXES VÀ MATERIALIZED VIEWS
-- =============================================================================
-- File: supabase/migrations/20241225000001_add_performance_indexes.sql

-- 1. COMPOUND INDEXES CHO CÁC QUERY PATTERN THƯỜNG DÙNG
CREATE INDEX CONCURRENTLY idx_products_category_active 
ON products (category, is_active) WHERE is_active = true;

CREATE INDEX CONCURRENTLY idx_products_category_price 
ON products (category, current_price, is_active) WHERE is_active = true;

CREATE INDEX CONCURRENTLY idx_products_search_category 
ON products (category, search_vector) WHERE is_active = true;

-- 2. JSONB INDEXES CHO ATTRIBUTES
CREATE INDEX CONCURRENTLY idx_products_jsonb_gin 
ON products USING gin (attributes);

-- Index riêng cho từng loại sản phẩm
CREATE INDEX CONCURRENTLY idx_fertilizer_npk 
ON products USING gin ((attributes->'npk_ratio')) 
WHERE category = 'FERTILIZER' AND is_active = true;

CREATE INDEX CONCURRENTLY idx_pesticide_ingredient 
ON products USING gin ((attributes->'active_ingredient')) 
WHERE category = 'PESTICIDE' AND is_active = true;

CREATE INDEX CONCURRENTLY idx_seed_variety 
ON products USING gin ((attributes->'variety')) 
WHERE category = 'SEED' AND is_active = true;

-- 3. INDEXES CHO INVENTORY TRACKING
CREATE INDEX CONCURRENTLY idx_product_batches_product_fifo 
ON product_batches (product_id, received_date ASC, is_available) 
WHERE is_available = true;

CREATE INDEX CONCURRENTLY idx_product_batches_expiry 
ON product_batches (expiry_date ASC, is_available) 
WHERE is_available = true AND expiry_date IS NOT NULL;

-- 4. TRANSACTION INDEXES
CREATE INDEX CONCURRENTLY idx_transactions_customer_date 
ON transactions (customer_id, created_at DESC);

CREATE INDEX CONCURRENTLY idx_transactions_date_payment 
ON transactions (created_at DESC, payment_method);

-- 5. MATERIALIZED VIEW CHO DASHBOARD STATS
CREATE MATERIALIZED VIEW product_dashboard_stats AS
SELECT 
  category,
  COUNT(*) as total_products,
  SUM(CASE WHEN available_stock > 0 THEN 1 ELSE 0 END) as in_stock_products,
  SUM(CASE WHEN available_stock < 10 THEN 1 ELSE 0 END) as low_stock_count,
  AVG(current_price) as avg_price,
  SUM(available_stock) as total_stock_value,
  MAX(created_at) as last_updated
FROM products_with_details 
WHERE is_active = true
GROUP BY category
UNION ALL
SELECT 
  'TOTAL' as category,
  COUNT(*) as total_products,
  SUM(CASE WHEN available_stock > 0 THEN 1 ELSE 0 END) as in_stock_products,
  SUM(CASE WHEN available_stock < 10 THEN 1 ELSE 0 END) as low_stock_count,
  AVG(current_price) as avg_price,
  SUM(available_stock) as total_stock_value,
  MAX(created_at) as last_updated
FROM products_with_details 
WHERE is_active = true;

-- Index cho materialized view
CREATE INDEX idx_product_dashboard_stats_category 
ON product_dashboard_stats (category);

-- 6. FUNCTION ĐỂ REFRESH MATERIALIZED VIEW
CREATE OR REPLACE FUNCTION refresh_dashboard_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY product_dashboard_stats;
END;
$$ LANGUAGE plpgsql;

-- 7. RLS POLICIES CHO PERFORMANCE
-- Tạo policy tối ưu cho select operations
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON products;
CREATE POLICY "optimized_select_products" ON products
    FOR SELECT USING (
        auth.role() = 'authenticated' AND is_active = true
    );

-- 8. STATISTICS UPDATE
-- Cập nhật statistics cho query planner
ANALYZE products;
ANALYZE product_batches;
ANALYZE transactions;
ANALYZE transaction_items;
