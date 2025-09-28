-- =============================================================================
-- FIX MULTI-TENANT RLS POLICIES
-- =============================================================================
-- Purpose: Update RLS policies to allow proper multi-tenant authentication flow
-- while maintaining security for authenticated operations
-- =============================================================================

-- =============================================================================
-- 1. UPDATE STORES RLS POLICIES
-- =============================================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Users can only see stores they own" ON stores;
DROP POLICY IF EXISTS "Users can only create stores for themselves" ON stores;
DROP POLICY IF EXISTS "Users can only update stores they own" ON stores;

-- Create new policies that support multi-tenant authentication
CREATE POLICY "Enable read access for authenticated users on stores"
    ON stores FOR SELECT
    TO authenticated
    USING (true);  -- Allow reading any store for authenticated users

CREATE POLICY "Enable insert for authenticated users on stores"
    ON stores FOR INSERT
    TO authenticated
    WITH CHECK (true);  -- Allow creating stores

CREATE POLICY "Enable update for store owners only"
    ON stores FOR UPDATE
    TO authenticated
    USING (
        -- Only allow updates if user is owner of the store
        id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid()
            AND role = 'OWNER'
            AND is_active = true
        )
    );

CREATE POLICY "Enable delete for store owners only"
    ON stores FOR DELETE
    TO authenticated
    USING (
        -- Only allow deletion if user is owner of the store
        id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid()
            AND role = 'OWNER'
            AND is_active = true
        )
    );

-- =============================================================================
-- 2. UPDATE USER_PROFILES RLS POLICIES
-- =============================================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Users can only see their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can only update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Allow user profile creation during registration" ON user_profiles;

-- Create new policies for multi-tenant access
CREATE POLICY "Users can view profiles in same store" FOR SELECT
    ON user_profiles
    TO authenticated
    USING (
        -- Allow viewing profiles in the same store
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid()
            AND is_active = true
        )
    );

CREATE POLICY "Allow user profile creation during registration" FOR INSERT
    ON user_profiles
    TO authenticated
    WITH CHECK (true);  -- Allow profile creation during signup

CREATE POLICY "Users can update own profile" FOR UPDATE
    ON user_profiles
    TO authenticated
    USING (id = auth.uid());

CREATE POLICY "Managers can manage users in same store"
    ON user_profiles
    FOR ALL
    TO authenticated
    USING (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('OWNER', 'MANAGER')
            AND is_active = true
        )
    )
    WITH CHECK (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid()
            AND role IN ('OWNER', 'MANAGER')
            AND is_active = true
        )
    );

-- =============================================================================
-- 3. CREATE HELPER FUNCTION FOR AUTHENTICATION
-- =============================================================================

-- Function to get user's store ID for RLS policies
CREATE OR REPLACE FUNCTION get_user_store_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    user_store_id UUID;
BEGIN
    -- Get store_id from user_profiles for current user
    SELECT store_id INTO user_store_id
    FROM user_profiles
    WHERE id = auth.uid()
    AND is_active = true;

    RETURN user_store_id;
END;
$$;

-- =============================================================================
-- 4. CREATE TEST STORE IF NOT EXISTS
-- =============================================================================

-- Ensure test store exists for testing
INSERT INTO stores (
    store_code,
    store_name,
    owner_name,
    is_active,
    subscription_type,
    created_at,
    updated_at
) VALUES (
    'hungpham',
    'Cửa hàng test của Hưng Phạm',
    'Hưng Phạm',
    true,
    'FREE',
    NOW(),
    NOW()
) ON CONFLICT (store_code) DO UPDATE SET
    store_name = EXCLUDED.store_name,
    owner_name = EXCLUDED.owner_name,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- =============================================================================
-- 5. VERIFICATION
-- =============================================================================

-- Test RLS policies
DO $$
DECLARE
    store_count INTEGER;
    policy_count INTEGER;
BEGIN
    -- Check if stores exist
    SELECT COUNT(*) INTO store_count FROM stores WHERE store_code = 'hungpham';
    RAISE NOTICE 'Test stores count: %', store_count;

    -- Check if policies exist
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename IN ('stores', 'user_profiles');
    RAISE NOTICE 'Total RLS policies count: %', policy_count;

    IF store_count > 0 AND policy_count > 0 THEN
        RAISE NOTICE 'RLS policies and test data setup completed successfully!';
    ELSE
        RAISE WARNING 'Setup may be incomplete. Store count: %, Policy count: %', store_count, policy_count;
    END IF;
END $$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_store_id() TO authenticated;