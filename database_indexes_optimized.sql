-- =============================================================================
-- DATABASE INDEXES OPTIMIZATION - SỬA LỖI SCHEMA
-- =============================================================================
-- Run này sau khi đã có pagination và full-text search

-- ==========================================
-- 1. COMPOSITE INDEXES CHO QUERIES PHỔ BIẾN
-- ==========================================

-- Products table (base table chỉ có các cột cơ bản)
CREATE INDEX idx_products_category_active ON products(category, is_active) WHERE is_active = true;
CREATE INDEX idx_products_category_created ON products(category, created_at DESC) WHERE is_active = true;
CREATE INDEX idx_products_sku_unique ON products(sku) WHERE sku IS NOT NULL AND is_active = true;
CREATE INDEX idx_products_company_category ON products(company_id, category) WHERE is_active = true;

-- Full-text search index cho Vietnamese
CREATE INDEX idx_products_name_search ON products USING gin(to_tsvector('vietnamese', name || ' ' || COALESCE(description, '')));

-- JSONB attributes index (cho flexible schema)
CREATE INDEX idx_products_attributes_gin ON products USING gin(attributes);

-- Specific attribute indexes cho từng category
CREATE INDEX idx_products_fertilizer_npk ON products USING gin((attributes->'npk_ratio'))
WHERE category = 'FERTILIZER' AND is_active = true;

CREATE INDEX idx_products_pesticide_ingredient ON products USING gin((attributes->'active_ingredient'))
WHERE category = 'PESTICIDE' AND is_active = true;

CREATE INDEX idx_products_seed_variety ON products USING gin((attributes->'seed_strain'))
WHERE category = 'SEED' AND is_active = true;

-- ==========================================
-- 2. TRANSACTIONS TABLE INDEXES
-- ==========================================

-- Most common queries: recent transactions by customer
CREATE INDEX idx_transactions_date_customer ON transactions(transaction_date DESC, customer_id);

-- Payment method analysis
CREATE INDEX idx_transactions_payment_date ON transactions(payment_method, transaction_date DESC);

-- Invoice number lookup (exact match)
CREATE INDEX idx_transactions_invoice ON transactions(invoice_number) WHERE invoice_number IS NOT NULL;

-- Debt tracking
CREATE INDEX idx_transactions_debt_date ON transactions(is_debt, transaction_date DESC) WHERE is_debt = true;

-- Monthly/daily reports
CREATE INDEX idx_transactions_date_only ON transactions(DATE(transaction_date), total_amount);

-- ==========================================
-- 3. TRANSACTION ITEMS INDEXES
-- ==========================================

-- Join with transactions
CREATE INDEX idx_transaction_items_transaction ON transaction_items(transaction_id);

-- Product sales analysis
CREATE INDEX idx_transaction_items_product ON transaction_items(product_id, transaction_id);

-- Combined for reporting
CREATE INDEX idx_transaction_items_product_date ON transaction_items(product_id, created_at DESC);

-- ==========================================
-- 4. PRODUCT BATCHES (INVENTORY) INDEXES
-- ==========================================

-- FIFO inventory management
CREATE INDEX idx_batches_product_fifo ON product_batches(product_id, received_date ASC)
WHERE is_available = true AND quantity > 0;

-- Expiry date tracking
CREATE INDEX idx_batches_expiry_alert ON product_batches(expiry_date ASC, product_id)
WHERE is_available = true AND expiry_date IS NOT NULL;

-- Available stock calculation
CREATE INDEX idx_batches_available_stock ON product_batches(is_available, quantity, product_id)
WHERE is_available = true;

-- Supplier tracking
CREATE INDEX idx_batches_supplier_date ON product_batches(supplier, received_date DESC);

-- ==========================================
-- 5. SEASONAL PRICES INDEXES
-- ==========================================

-- Current price lookup (most important)
CREATE INDEX idx_seasonal_prices_current ON seasonal_prices(product_id, effective_date DESC, is_active)
WHERE is_active = true;

-- Price history analysis
CREATE INDEX idx_seasonal_prices_product_history ON seasonal_prices(product_id, effective_date DESC);

-- ==========================================
-- 6. PARTIAL INDEXES CHO FILTERED QUERIES
-- ==========================================

-- Active products only (90% of queries)
CREATE INDEX idx_products_active_category_name ON products(category, name)
WHERE is_active = true;

-- Recent transactions only (most dashboard queries)
CREATE INDEX idx_transactions_recent ON transactions(transaction_date DESC, total_amount)
WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days';

-- Low stock products (critical alerts)
CREATE INDEX idx_products_low_stock ON products(id, name, category)
WHERE is_active = true; -- We'll use the view for available_stock

-- In-stock products only
CREATE INDEX idx_products_in_stock ON products(category, name)
WHERE is_active = true; -- Available stock calculated in view

-- Debt transactions only
CREATE INDEX idx_transactions_debt_customer ON transactions(customer_id, transaction_date DESC)
WHERE is_debt = true;

-- ==========================================
-- 7. VIEWS OPTIMIZATION INDEXES
-- ==========================================

-- Index for products_with_details view performance
CREATE INDEX idx_products_view_optimization ON products(id, category, name, is_active, company_id);

-- ==========================================
-- 8. STATISTICS UPDATE
-- ==========================================

-- Update statistics for query planner
ANALYZE products;
ANALYZE product_batches;
ANALYZE transactions;
ANALYZE transaction_items;
ANALYZE seasonal_prices;

-- ==========================================
-- 9. MAINTENANCE COMMANDS
-- ==========================================

-- Reindex concurrent để không block traffic
-- REINDEX INDEX CONCURRENTLY idx_products_category_active;
-- REINDEX INDEX CONCURRENTLY idx_transactions_date_customer;
-- REINDEX INDEX CONCURRENTLY idx_products_name_search;

-- Vacuum full cho performance (chạy off-peak hours)
-- VACUUM FULL products;
-- VACUUM FULL transactions;
-- VACUUM FULL product_batches;

-- ==========================================
-- 10. MONITORING QUERIES
-- ==========================================

-- Check index usage
-- SELECT
--   schemaname,
--   tablename,
--   indexname,
--   idx_scan,
--   idx_tup_read,
--   idx_tup_fetch
-- FROM pg_stat_user_indexes
-- ORDER BY idx_scan DESC;

-- Check table sizes
-- SELECT
--   schemaname,
--   tablename,
--   pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- =============================================================================
-- NOTES:
-- 1. Không index trên current_price trong bảng products vì nó không tồn tại
-- 2. current_price chỉ có trong view products_with_details
-- 3. available_stock cũng được calculated trong view
-- 4. Dùng CONCURRENTLY để không block production traffic
-- 5. Monitor index usage định kỳ và drop unused indexes
-- =============================================================================