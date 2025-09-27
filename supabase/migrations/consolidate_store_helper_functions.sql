-- =============================================================================
-- CONSOLIDATE STORE HELPER FUNCTIONS
-- Fix conflicting get_user_store_id vs get_current_user_store_id
-- =============================================================================

-- Drop any existing variations
DROP FUNCTION IF EXISTS get_current_user_store_id();
DROP FUNCTION IF EXISTS get_user_store_id();

-- Create single canonical function
CREATE OR REPLACE FUNCTION get_current_user_store_id()
RETURNS UUID 
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    user_store_id UUID;
BEGIN
    -- Get store_id from user_profiles (most reliable method)
    SELECT store_id INTO user_store_id
    FROM user_profiles
    WHERE id = auth.uid()
    AND is_active = true
    LIMIT 1;
    
    RETURN user_store_id;
END; $$;

-- Create alias for backward compatibility
CREATE OR REPLACE FUNCTION get_user_store_id()
RETURNS UUID 
LANGUAGE sql SECURITY DEFINER AS $$
    SELECT get_current_user_store_id();
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_current_user_store_id() TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_store_id() TO authenticated;

-- Update all RLS policies to use canonical function
-- This ensures consistency across all tables

-- Drop existing policies that might use different functions
DO $$ 
DECLARE
    table_name TEXT;
    policy_name TEXT;
BEGIN
    -- List of business tables
    FOR table_name IN 
        SELECT unnest(ARRAY[
            'products', 'customers', 'transactions', 'transaction_items',
            'purchase_orders', 'purchase_order_items', 'companies', 
            'product_batches', 'seasonal_prices'
        ])
    LOOP
        -- Drop existing multi-tenant policies
        EXECUTE format('DROP POLICY IF EXISTS "Multi-tenant isolation" ON %I', table_name);
        EXECUTE format('DROP POLICY IF EXISTS "%s_select_own" ON %I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "%s_insert_own" ON %I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "%s_update_own" ON %I', table_name, table_name);
        EXECUTE format('DROP POLICY IF EXISTS "%s_delete_own" ON %I', table_name, table_name);
        
        -- Create unified store isolation policy
        EXECUTE format('
            CREATE POLICY "store_isolation_policy" ON %I
            FOR ALL TO authenticated
            USING (store_id = get_current_user_store_id())
            WITH CHECK (store_id = get_current_user_store_id())
        ', table_name);
        
        RAISE NOTICE 'Updated RLS policy for table: %', table_name;
    END LOOP;
END $$;

-- Verify RLS is enabled on all tables
DO $$
DECLARE
    table_name TEXT;
BEGIN
    FOR table_name IN 
        SELECT unnest(ARRAY[
            'products', 'customers', 'transactions', 'transaction_items',
            'purchase_orders', 'purchase_order_items', 'companies', 
            'product_batches', 'seasonal_prices'
        ])
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', table_name);
        RAISE NOTICE 'RLS enabled for table: %', table_name;
    END LOOP;
END $$;