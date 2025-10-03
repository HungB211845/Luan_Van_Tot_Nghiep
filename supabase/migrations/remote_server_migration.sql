-- =============================================================================
-- REMOTE SUPABASE SERVER MIGRATION
-- =============================================================================
-- Copy và paste toàn bộ file này vào Supabase SQL Editor để setup database

-- =============================================================================
-- 1. CREATE STORES TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS stores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    store_code TEXT UNIQUE NOT NULL,
    store_name TEXT NOT NULL,
    owner_name TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    business_license TEXT,
    tax_code TEXT,
    subscription_type TEXT DEFAULT 'FREE' CHECK (subscription_type IN ('FREE', 'BASIC', 'PREMIUM')),
    subscription_expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 2. CREATE USER PROFILES TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    role TEXT NOT NULL DEFAULT 'STAFF' CHECK (role IN ('OWNER', 'MANAGER', 'STAFF')),
    permissions JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 3. CREATE USER SESSIONS TABLE
-- =============================================================================
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    device_type TEXT,
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- =============================================================================
-- 4. ENABLE RLS
-- =============================================================================
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 5. CREATE INDEXES
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_stores_store_code ON stores (store_code);
CREATE INDEX IF NOT EXISTS idx_stores_active ON stores (is_active);
CREATE INDEX IF NOT EXISTS idx_user_profiles_store_id ON user_profiles (store_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_active ON user_profiles (is_active);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions (user_id);

-- =============================================================================
-- 6. CREATE RPC FUNCTION FOR STORE VALIDATION
-- =============================================================================
CREATE OR REPLACE FUNCTION validate_store_for_login(store_code_param TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- This bypasses RLS policies
AS $$
DECLARE
    store_record RECORD;
    result JSON;
BEGIN
    -- Validate input
    IF store_code_param IS NULL OR trim(store_code_param) = '' THEN
        RETURN json_build_object(
            'valid', false,
            'error', 'Store code is required'
        );
    END IF;

    -- Find store by store_code (case-insensitive)
    SELECT * INTO store_record
    FROM stores
    WHERE LOWER(store_code) = LOWER(trim(store_code_param))
    AND is_active = true;

    -- Check if store exists
    IF NOT FOUND THEN
        RETURN json_build_object(
            'valid', false,
            'error', 'Store not found or inactive'
        );
    END IF;

    -- Return store data for authentication flow
    result := json_build_object(
        'valid', true,
        'store_data', json_build_object(
            'id', store_record.id,
            'store_code', store_record.store_code,
            'store_name', store_record.store_name,
            'owner_name', store_record.owner_name,
            'phone', store_record.phone,
            'email', store_record.email,
            'address', store_record.address,
            'business_license', store_record.business_license,
            'tax_code', store_record.tax_code,
            'subscription_type', store_record.subscription_type,
            'subscription_expires_at', store_record.subscription_expires_at,
            'is_active', store_record.is_active,
            'created_at', store_record.created_at,
            'updated_at', store_record.updated_at
        )
    );

    RETURN result;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return failure
        RAISE LOG 'Error in validate_store_for_login: %', SQLERRM;
        RETURN json_build_object(
            'valid', false,
            'error', 'Internal server error'
        );
END;
$$;

-- =============================================================================
-- 7. CREATE RLS POLICIES
-- =============================================================================

-- STORES TABLE POLICIES
DROP POLICY IF EXISTS "Allow authenticated users to read stores" ON stores;
DROP POLICY IF EXISTS "Allow public store validation" ON stores;

CREATE POLICY "Allow authenticated users to read stores"
    ON stores FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Allow public store validation"
    ON stores FOR SELECT
    TO public
    USING (true);

-- USER_PROFILES TABLE POLICIES
DROP POLICY IF EXISTS "Users can read own profile" ON user_profiles;
DROP POLICY IF EXISTS "Allow profile creation" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Service role full access" ON user_profiles;

CREATE POLICY "Users can read own profile"
    ON user_profiles FOR SELECT
    TO authenticated
    USING (id = auth.uid());

CREATE POLICY "Allow profile creation"
    ON user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (id = auth.uid());

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

CREATE POLICY "Service role full access"
    ON user_profiles FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- USER_SESSIONS TABLE POLICIES
DROP POLICY IF EXISTS "Users can manage their own sessions" ON user_sessions;

CREATE POLICY "Users can manage their own sessions"
    ON user_sessions FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- =============================================================================
-- 8. GRANT PERMISSIONS
-- =============================================================================

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION validate_store_for_login(TEXT) TO authenticated;

-- Grant execute permission to anonymous users (for login flow)
GRANT EXECUTE ON FUNCTION validate_store_for_login(TEXT) TO anon;

-- =============================================================================
-- 9. INSERT TEST DATA (OPTIONAL)
-- =============================================================================

-- Insert test store
INSERT INTO stores (
    store_code,
    store_name,
    owner_name,
    is_active,
    subscription_type
) VALUES (
    'hungpham',
    'Cửa hàng test của Hưng Phạm',
    'Hưng Phạm',
    true,
    'FREE'
) ON CONFLICT (store_code) DO UPDATE SET
    store_name = EXCLUDED.store_name,
    owner_name = EXCLUDED.owner_name,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- =============================================================================
-- 10. VERIFICATION
-- =============================================================================

-- Test the RPC function
SELECT validate_store_for_login('hungpham') as test_result;

-- Check tables
SELECT 'stores' as table_name, count(*) as row_count FROM stores
UNION ALL
SELECT 'user_profiles' as table_name, count(*) as row_count FROM user_profiles
UNION ALL
SELECT 'user_sessions' as table_name, count(*) as row_count FROM user_sessions;

-- Check policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename IN ('stores', 'user_profiles', 'user_sessions');

-- Success message
SELECT 'Migration completed successfully! You can now test login with store code: hungpham' as status;