-- Migration: Dashboard Product Redesign
-- Date: 2025-10-03
-- Purpose: Transform ProductDetailScreen from tabs to dashboard-first approach
-- Author: Claude following specifications in conversation

-- =====================================================
-- 1. PRODUCTS TABLE UPDATES
-- =====================================================

-- Add current_selling_price column to products table
-- This replaces the complex seasonal_price relationship
ALTER TABLE products
ADD COLUMN current_selling_price NUMERIC DEFAULT 0 NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN products.current_selling_price IS 'Giá bán hiện tại được áp dụng tại POS, thay thế seasonal pricing phức tạp';

-- =====================================================
-- 2. PRICE HISTORY TRACKING
-- =====================================================

-- Create price_history table for audit trail
CREATE TABLE IF NOT EXISTS price_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    new_price NUMERIC NOT NULL,
    old_price NUMERIC,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id_who_changed UUID,
    store_id UUID NOT NULL,
    reason TEXT DEFAULT 'Manual price update',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX idx_price_history_product_id ON price_history(product_id);
CREATE INDEX idx_price_history_store_id ON price_history(store_id);
CREATE INDEX idx_price_history_changed_at ON price_history(changed_at DESC);

-- Add RLS policy for price_history
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view price history for their store" ON price_history
    FOR SELECT USING (
        store_id = (SELECT store_id FROM user_profiles WHERE id = auth.uid())
    );

CREATE POLICY "Users can insert price history for their store" ON price_history
    FOR INSERT WITH CHECK (
        store_id = (SELECT store_id FROM user_profiles WHERE id = auth.uid())
    );

-- =====================================================
-- 3. INVENTORY ADJUSTMENTS SYSTEM
-- =====================================================

-- Create inventory_adjustments table for soft delete and void operations
CREATE TABLE IF NOT EXISTS inventory_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES product_batches(id) ON DELETE CASCADE,
    quantity_change NUMERIC NOT NULL,
    reason TEXT NOT NULL,
    adjustment_type VARCHAR(50) DEFAULT 'manual' CHECK (adjustment_type IN ('manual', 'void_batch', 'stock_correction', 'damage', 'theft')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id_who_adjusted UUID,
    store_id UUID NOT NULL,
    notes TEXT
);

-- Add indexes for performance
CREATE INDEX idx_inventory_adjustments_batch_id ON inventory_adjustments(batch_id);
CREATE INDEX idx_inventory_adjustments_store_id ON inventory_adjustments(store_id);
CREATE INDEX idx_inventory_adjustments_created_at ON inventory_adjustments(created_at DESC);

-- Add RLS policy for inventory_adjustments
ALTER TABLE inventory_adjustments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view inventory adjustments for their store" ON inventory_adjustments
    FOR SELECT USING (
        store_id = (SELECT store_id FROM user_profiles WHERE id = auth.uid())
    );

CREATE POLICY "Users can insert inventory adjustments for their store" ON inventory_adjustments
    FOR INSERT WITH CHECK (
        store_id = (SELECT store_id FROM user_profiles WHERE id = auth.uid())
    );
-- =====================================================
-- 4. PRODUCT BATCHES ENHANCEMENTS
-- =====================================================

-- Add sales tracking and soft delete support to product_batches
ALTER TABLE product_batches
ADD COLUMN IF NOT EXISTS sales_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false;

-- Add comments for documentation
COMMENT ON COLUMN product_batches.sales_count IS 'Số lượng giao dịch bán đã phát sinh từ lô hàng này';
COMMENT ON COLUMN product_batches.is_deleted IS 'Đánh dấu lô hàng đã bị xóa mềm (soft delete)';

-- Create index for performance queries
CREATE INDEX idx_product_batches_is_deleted ON product_batches(is_deleted) WHERE is_deleted = false;
CREATE INDEX idx_product_batches_sales_count ON product_batches(sales_count);

-- =====================================================
-- 5. HELPER FUNCTIONS
-- =====================================================

-- Function to calculate average cost price for a product
CREATE OR REPLACE FUNCTION get_average_cost_price(p_product_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    avg_cost NUMERIC;
BEGIN
    SELECT COALESCE(
        SUM(pb.cost_price * pb.quantity) / NULLIF(SUM(pb.quantity), 0),
        0
    ) INTO avg_cost
    FROM product_batches pb
    WHERE pb.product_id = p_product_id
      AND pb.is_deleted = false
      AND pb.quantity > 0;

    RETURN COALESCE(avg_cost, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to calculate gross profit percentage
CREATE OR REPLACE FUNCTION get_gross_profit_percentage(p_product_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    selling_price NUMERIC;
    avg_cost NUMERIC;
    profit_percentage NUMERIC;
BEGIN
    -- Get current selling price
    SELECT current_selling_price INTO selling_price
    FROM products
    WHERE id = p_product_id;

    -- Get average cost price
    SELECT get_average_cost_price(p_product_id) INTO avg_cost;

    -- Calculate profit percentage
    IF avg_cost > 0 THEN
        profit_percentage := ((selling_price - avg_cost) / avg_cost) * 100;
    ELSE
        profit_percentage := 0;
    END IF;

    RETURN ROUND(profit_percentage, 2);
END;
$$ LANGUAGE plpgsql;

-- Function to update product selling price with history tracking
CREATE OR REPLACE FUNCTION update_product_selling_price(
    p_product_id UUID,
    p_new_price NUMERIC,
    p_user_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT 'Manual price update'
)
RETURNS BOOLEAN AS $$
DECLARE
    old_price NUMERIC;
    product_store_id UUID;
BEGIN
    -- Get current price and store_id
    SELECT current_selling_price, store_id INTO old_price, product_store_id
    FROM products
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found';
    END IF;

    -- Update product price
    UPDATE products
    SET current_selling_price = p_new_price,
        updated_at = NOW()
    WHERE id = p_product_id;

    -- Insert price history record
    INSERT INTO price_history (
        product_id,
        new_price,
        old_price,
        user_id_who_changed,
        store_id,
        reason
    ) VALUES (
        p_product_id,
        p_new_price,
        old_price,
        p_user_id,
        product_store_id,
        p_reason
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. DATA MIGRATION (if needed)
-- =====================================================

-- Update existing products with current_selling_price from seasonal_prices
-- This is a one-time migration to populate the new column
UPDATE products p
SET current_selling_price = COALESCE(
    (SELECT sp.selling_price
     FROM seasonal_prices sp
     WHERE sp.product_id = p.id
       AND sp.is_active = true
       AND sp.start_date <= NOW()
       AND (sp.end_date IS NULL OR sp.end_date >= NOW())
     ORDER BY sp.created_at DESC
     LIMIT 1),
    0
)
WHERE current_selling_price = 0;

-- =====================================================
-- 7. VERIFICATION QUERIES
-- =====================================================

-- Verify the schema changes
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name IN ('products', 'price_history', 'inventory_adjustments', 'product_batches')
  AND column_name IN ('current_selling_price', 'sales_count', 'is_deleted')
ORDER BY table_name, ordinal_position;

-- Test the helper functions
SELECT
    'Helper functions created successfully' as status,
    COUNT(*) as function_count
FROM information_schema.routines
WHERE routine_name IN ('get_average_cost_price', 'get_gross_profit_percentage', 'update_product_selling_price');

-- Show sample data after migration
SELECT
    p.name,
    p.current_selling_price,
    get_average_cost_price(p.id) as avg_cost,
    get_gross_profit_percentage(p.id) as profit_percentage
FROM products p
LIMIT 5;