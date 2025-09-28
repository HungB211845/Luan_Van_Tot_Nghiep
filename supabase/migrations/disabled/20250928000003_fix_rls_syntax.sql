-- =============================================================================
-- FIX RLS POLICY SYNTAX ERRORS
-- =============================================================================

-- Fix user_profiles policies with correct syntax
DROP POLICY IF EXISTS "Users can view profiles in same store" ON user_profiles;
DROP POLICY IF EXISTS "Allow user profile creation during registration" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;

-- Create user_profiles policies with correct syntax
CREATE POLICY "Users can view profiles in same store"
    ON user_profiles FOR SELECT
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

CREATE POLICY "Allow user profile creation during registration"
    ON user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (true);  -- Allow profile creation during signup

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid());

-- Test the policies
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename IN ('stores', 'user_profiles');
    RAISE NOTICE 'Total RLS policies after fix: %', policy_count;
END $$;