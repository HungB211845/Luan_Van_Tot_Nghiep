-- =============================================================================
-- BASIC RLS POLICIES FOR AUTHENTICATION
-- =============================================================================

-- =============================================================================
-- 1. STORES TABLE POLICIES
-- =============================================================================

-- Allow reading stores for authentication purposes
CREATE POLICY "Allow authenticated users to read stores"
    ON stores FOR SELECT
    TO authenticated
    USING (true);

-- Allow public access for store validation (RPC function)
CREATE POLICY "Allow public store validation"
    ON stores FOR SELECT
    TO public
    USING (true);

-- =============================================================================
-- 2. USER_PROFILES TABLE POLICIES
-- =============================================================================

-- Allow users to read their own profile
CREATE POLICY "Users can read their own profile"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (id = auth.uid());

-- Allow users in the same store to see each other
CREATE POLICY "Users can read profiles in same store"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (
        store_id IN (
            SELECT store_id
            FROM user_profiles
            WHERE id = auth.uid()
            AND is_active = true
        )
    );

-- Allow profile creation during registration
CREATE POLICY "Allow profile creation during registration"
    ON user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Allow users to update their own profile
CREATE POLICY "Users can update their own profile"
    ON user_profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid());

-- =============================================================================
-- 3. USER_SESSIONS TABLE POLICIES
-- =============================================================================

-- Allow users to manage their own sessions
CREATE POLICY "Users can manage their own sessions"
    ON user_sessions FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- =============================================================================
-- 4. VERIFICATION
-- =============================================================================

-- Test the policies
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename IN ('stores', 'user_profiles', 'user_sessions');
    RAISE NOTICE 'Total RLS policies created: %', policy_count;
END $$;