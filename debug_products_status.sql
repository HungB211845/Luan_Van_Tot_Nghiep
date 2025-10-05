-- =============================================================================
-- DEBUG QUERY: Check Database Products Status
-- Date: 2025-10-05
-- Purpose: Debug why POS Screen cannot load products
-- =============================================================================
-- Check 1: Basic products count
SELECT
    'Total Products' as check_type,
    COUNT(*) as count,
    COUNT(
        CASE
            WHEN is_active = true THEN 1
        END
    ) as active_count
FROM
    public.products;

-- Check 2: Products with details view
SELECT
    'Products With Details View' as check_type,
    COUNT(*) as count
FROM
    public.products_with_details;

-- Check 3: Sample products data
SELECT
    'Sample Products' as check_type,
    id,
    name,
    sku,
    current_selling_price,
    is_active,
    store_id
FROM
    public.products
WHERE
    is_active = true LIMIT 5;

-- Check 4: Check if RLS is blocking access
SELECT
    'RLS Policies Check' as check_type,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM
    pg_policies
WHERE
    tablename = 'products';

-- Check 5: Check current user authentication
SELECT
    'Current User' as check_type,
    auth.uid () as user_id,
    (
        SELECT
            store_id
        FROM
            user_profiles
        WHERE
            id = auth.uid ()
    ) as user_store_id;

-- Check 6: Products accessible to current user
SELECT
    'User Accessible Products' as check_type,
    COUNT(*) as count
FROM
    public.products p
WHERE
    p.store_id = (
        SELECT
            store_id
        FROM
            user_profiles
        WHERE
            id = auth.uid ()
    )
    AND p.is_active = true;

-- Check 7: Check views exist
SELECT
    'Views Status' as check_type,
    table_name,
    table_type
FROM
    information_schema.tables
WHERE
    table_schema = 'public'
    AND table_name IN (
        'products_with_details',
        'low_stock_products',
        'expiring_batches'
    );

-- Check 8: Check if products_with_details query works
SELECT
    'Products With Details Sample' as check_type,
    id,
    name,
    available_stock,
    current_selling_price
FROM
    public.products_with_details LIMIT 3;