-- =============================================================================
-- FIX INFINITE RECURSION IN RLS POLICIES
-- =============================================================================

-- =============================================================================
-- 1. DROP PROBLEMATIC POLICIES
-- =============================================================================

-- Drop the recursive policies
DROP POLICY IF EXISTS "Users can read profiles in same store" ON user_profiles;
DROP POLICY IF EXISTS "Users can read their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Allow profile creation during registration" ON user_profiles;

-- =============================================================================
-- 2. CREATE SIMPLE NON-RECURSIVE POLICIES
-- =============================================================================

-- Allow users to read their own profile (simple check)
CREATE POLICY "Users can read own profile"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (id = auth.uid());

-- Allow profile creation (for signup flow)
CREATE POLICY "Allow profile creation"
    ON user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (id = auth.uid());

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Allow service role full access (for admin operations)
CREATE POLICY "Service role full access"
    ON user_profiles FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- =============================================================================
-- 3. VERIFICATION
-- =============================================================================

-- Test the policies
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'user_profiles';
    RAISE NOTICE 'User profiles policies count: %', policy_count;
END $$;