-- =============================================================================
-- ENABLE FULL-TEXT SEARCH FOR PRODUCTS TABLE  
-- =============================================================================
-- File: supabase/migrations/enable_fulltext_search.sql

-- 1. CREATE OR REPLACE TRIGGER FUNCTION TO UPDATE search_vector
CREATE OR REPLACE FUNCTION update_product_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    -- Use 'simple' config for better Vietnamese support
    -- Weight: A = highest (name, sku), B = medium (description), C = lowest (attributes)
    NEW.search_vector :=
        setweight(to_tsvector('simple', COALESCE(NEW.name, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.sku, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(NEW.attributes::text, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. CREATE TRIGGER TO AUTO-UPDATE search_vector ON INSERT/UPDATE
DROP TRIGGER IF EXISTS products_search_vector_trigger ON products;
CREATE TRIGGER products_search_vector_trigger
    BEFORE INSERT OR UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_product_search_vector();

-- 3. UPDATE EXISTING PRODUCTS TO POPULATE search_vector
UPDATE products SET 
    search_vector = 
        setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(sku, '')), 'A') ||
        setweight(to_tsvector('simple', COALESCE(description, '')), 'B') ||
        setweight(to_tsvector('simple', COALESCE(attributes::text, '')), 'C')
WHERE search_vector IS NULL;

-- 4. CREATE GIN INDEX FOR FAST FULL-TEXT SEARCH (if not exists)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_search_vector_gin 
ON products USING gin(search_vector);

-- 5. CREATE COMPOUND INDEX FOR CATEGORY + SEARCH (optimization)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_category_search_gin 
ON products USING gin(category, search_vector) WHERE is_active = true;

-- 6. ANALYZE TABLE TO UPDATE STATISTICS
ANALYZE products;

COMMIT;